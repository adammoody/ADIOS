#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

// xml parser
#include <mxml.h>

#include "binpack-general.h"
#include "binpack-utils.h"
#include "br-utils.h"
#include "bw-utils.h"
#include "adios.h"
#include "adios_transport_hooks.h"
#include "adios_internals.h"

static int adios_posix_initialized = 0;

struct adios_File_data_struct
{
    long long handle;   // used for read
    int f;              // used for write
    void * buffer;
    uint64_t buffer_size;
    uint64_t start;
    int last_var_write_yes; // was the last item asked to write a write="yes"?
};

void adios_posix_init (const char * parameters
                      ,struct adios_method_struct * method
                      )
{
    struct adios_File_data_struct * f;
    if (!adios_posix_initialized)
    {
        adios_posix_initialized = 1;
    }
    method->method_data = malloc (sizeof (struct adios_File_data_struct));
    f = (struct adios_File_data_struct *) method->method_data;
    f->f = -1;
    f->handle = 0;
    f->buffer = 0;
    f->buffer_size = 0;
    f->start = 0;
    f->last_var_write_yes = 0;
}

void adios_posix_open (struct adios_file_struct * fd
                      ,struct adios_method_struct * method
                      )
{
    char name [STR_LEN];
    struct adios_File_data_struct * f = (struct adios_File_data_struct *)
                                                          method->method_data;

    sprintf (name, "%s%s", method->base_path, fd->name);
    if (fd->mode == adios_mode_read)
    {
        f->handle = br_fopen (fd->name);
        if (!f->handle)
        {
            fprintf (stderr, "file not found: %s\n", fd->name);

            return;
        }
    }
    else
    {
        if (fd->mode == adios_mode_append)
        {
            struct stat s;
            if (stat (name, &s) == 0)
                fd->base_offset += s.st_size;
            f->f = open (name, O_WRONLY);
            if (f->f == -1)
            {
                f->f = open (name,  O_WRONLY | O_CREAT
                            ,  S_IRUSR | S_IWUSR
                             | S_IRGRP | S_IWGRP
                             | S_IROTH | S_IWOTH
                            );
                if (f->f == -1)
                {
                    fprintf (stderr, "adios_posix_open failed for "
                                     "base_path %s, name %s\n"
                            ,method->base_path, fd->name
                            );
                }
            }
        }
        else  // make sure we overwrite
        {
            f->f = open (name, O_WRONLY | O_CREAT | O_TRUNC
                        ,  S_IRUSR | S_IWUSR
                         | S_IRGRP | S_IWGRP
                         | S_IROTH | S_IWOTH
                        );
            if (f->f == -1)
            {
                fprintf (stderr, "adios_posix_open failed for "
                                 "base_path %s, name %s\n"
                        ,method->base_path, fd->name
                        );
            }
        }
    }
}

int adios_posix_should_buffer (struct adios_file_struct * fd
                              ,struct adios_method_struct * method
                              ,void * comm
                              )
{
    return 1;   // as far as we care, buffer
}

void adios_posix_write (struct adios_file_struct * fd
                       ,struct adios_var_struct * v
                       ,void * data
                       ,struct adios_method_struct * method
                       )
{
    if (v->got_buffer)
    {
        if (data != v->data)  // if the user didn't give back the same thing
        {
            if (v->free_data == adios_flag_yes)
            {
                free (v->data);
                adios_method_buffer_free (v->data_size);
            } 
        }
        else
        {
            // we already saved all of the info, so we're ok.
            return;
        } 
    }

    // nothing to do since we will use the shared buffer
}

void adios_posix_get_write_buffer (struct adios_file_struct * fd
                                  ,struct adios_var_struct * v
                                  ,uint64_t * size
                                  ,void ** buffer
                                  ,struct adios_method_struct * method
                                  )
{
    uint64_t mem_allowed;
    
    if (*size == 0)
    {
        *size = adios_size_of_var (v, (void *) "");
    }
    
    if (v->data && v->free_data)
    {
        adios_method_buffer_free (v->data_size);
        free (v->data);
    }
    
    mem_allowed = adios_method_buffer_alloc (*size);
    if (mem_allowed == *size)
    {
        *buffer = malloc (*size);
        if (!*buffer)
        {
            adios_method_buffer_free (mem_allowed);
            fprintf (stderr, "Out of memory allocating %llu bytes for %s\n"
                    ,*size, v->name
                    );
            v->got_buffer = adios_flag_no;
            v->free_data = adios_flag_no;
            v->data_size = 0;
            v->data = 0;
            *size = 0;
            *buffer = 0;
        }
        else
        {
            v->got_buffer = adios_flag_yes;
            v->free_data = adios_flag_yes;
            v->data_size = mem_allowed;
            v->data = *buffer;
        }
    }
    else
    {
        adios_method_buffer_free (mem_allowed);
        fprintf (stderr, "OVERFLOW: Cannot allocate requested buffer of %llu "
                         "bytes for %s\n"
                ,*size
                ,v->name
                );
        *size = 0;
        *buffer = 0;
    }
}

// for now, just use the ones used for parse buffer.  Should they
// need to change, we're ready
static void posix_read_pre_fetch (struct adios_bp_element_struct * element
                                 ,void ** buffer, uint64_t * buffer_size
                                 ,void * private_data
                                 )
{
    adios_pre_element_fetch (element, buffer, buffer_size, private_data);
}

// for now, just use the ones used for parse buffer.  Should they
// need to change, we're ready
static void posix_read_post_fetch (struct adios_bp_element_struct * element
                                  ,void * buffer, uint64_t buffer_size
                                  ,void * private_data
                                  )
{
    adios_post_element_fetch (element, buffer, buffer_size, private_data);
}

void adios_posix_read (struct adios_file_struct * fd
                      ,struct adios_var_struct * v
                      ,void * buffer
                      ,struct adios_method_struct * method
                      )
{
    v->data = buffer;
}

static void adios_posix_do_write (struct adios_file_struct * fd
                                 ,char * buffer
                                 ,uint64_t buffer_size
                                 ,struct adios_method_struct * method
                                 )
{
    struct adios_File_data_struct * md = (struct adios_File_data_struct *)
                                         method->method_data;
    write (md->f, fd->buffer_start, (fd->shared_buffer - fd->buffer_start + 1));
    write (md->f, buffer, buffer_size);
}

static void adios_posix_do_read (struct adios_file_struct * fd
                                ,struct adios_method_struct * method
                                )
{
    struct adios_File_data_struct * md = (struct adios_File_data_struct *)
                                         method->method_data;
    struct adios_var_struct * v = fd->group->vars;
    
    uint64_t element_size = 0;
    struct adios_bp_element_struct * element = NULL;
    struct adios_parse_buffer_struct data;

    data.vars = v;
    data.buffer = 0;
    data.buffer_len = 0;
    
    while ((element_size = br_get_next_element_specific (md->handle
                                                        ,posix_read_pre_fetch
                                                        ,posix_read_post_fetch
                                                        ,&data
                                                        ,&element
                                                        )
          ) != 0)
    {
        //printf ("element size: %d\n", element_size);
        //printf ("%s %s\n", adios_tag_to_string (element->tag), element->name);
        //printf ("\tPath: %s\n", element->path);

        br_free_element (element);
    }
    
    if (data.buffer)
        free (data.buffer);
}

void adios_posix_close (struct adios_file_struct * fd
                       ,struct adios_method_struct * method
                       )
{
    struct adios_File_data_struct * md = (struct adios_File_data_struct *)
                                                       method->method_data;

    struct adios_index_process_group_struct_v1 * pg_root = 0;
    struct adios_index_var_struct_v1 * vars_root = 0;

    if (fd->mode == adios_mode_write)
    {
        char * buffer = 0;
        uint64_t buffer_size = 0;
        uint64_t buffer_offset = 0;
        uint64_t index_start = (fd->shared_buffer - fd->buffer_start + 1);

        // build index
        adios_build_index_v1 (fd, &pg_root, &vars_root);
        // if collective, gather the indexes from the rest and call
        // adios_merge_index_v1 (&pg_root, &vars_root, new_pg, new_vars);
        adios_write_index_v1 (&buffer, &buffer_size, &buffer_offset
                             ,index_start, pg_root, vars_root
                             );
        adios_write_version_v1 (&buffer, &buffer_size, &buffer_offset);
        adios_posix_do_write (fd, buffer, buffer_size, method);

        free (buffer);

        adios_clear_index_v1 (pg_root, vars_root);
    }

    if (fd->mode == adios_mode_append)
    {
        char * buffer = 0;
        uint64_t buffer_size = 0;
        uint64_t buffer_offset = 0;
        uint64_t index_start = (fd->shared_buffer - fd->buffer_start + 1);

        // build index
        adios_build_index_v1 (fd, &pg_root, &vars_root);
        // merge in with old struct
        // merge in peers with old struct from initial read
        adios_write_index_v1 (&buffer, &buffer_size, &buffer_offset
                             ,index_start, pg_root, vars_root
                             );
        adios_write_version_v1 (&buffer, &buffer_size, &buffer_offset);
        adios_posix_do_write (fd, buffer, buffer_size, method);

        free (buffer);

        adios_clear_index_v1 (pg_root, vars_root);
    }

    if (fd->mode == adios_mode_read)
    {
        // read the index to find the place to start reading
        adios_posix_do_read (fd, method);
        struct adios_var_struct * v = fd->group->vars;
        while (v)
        {
            v->data = 0;
            v = v->next;
        }
    }

    if (md->f != -1)
    {
        close (md->f);
    }
    else
    {
        if (md->handle)
        {
            br_fclose (md->handle);
        }
    }

    md->f = -1;
    md->handle = 0;
    md->start = 0;
    md->last_var_write_yes = 0;
}

void adios_posix_finalize (int mype, struct adios_method_struct * method)
{
/* nothing to do here */
    if (adios_posix_initialized)
        adios_posix_initialized = 0;
}

void adios_posix_end_iteration (struct adios_method_struct * method)
{
}

void adios_posix_start_calculation (struct adios_method_struct * method)
{
}

void adios_posix_stop_calculation (struct adios_method_struct * method)
{
}
