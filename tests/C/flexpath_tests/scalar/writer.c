/**
 * writer.c
 *
 * ADIOS is freely available under the terms of the BSD license described
 * in the COPYING file in the top level directory of this source distribution.
 *
 * Copyright (c) 2008 - 2009.  UT-BATTELLE, LLC. All rights reserved.
 *
 *  Created on: Jul 1, 2013
 *  Author: Magda Slawinska aka Magic Magg magg dot gatech at gmail.com
 *
 * This is an example of writing an integer scalar. Each process
 * writes an integer which is its rank.
 */

#include "mpi.h"
#include "adios.h"
#include "adios_read.h"  // for adios_errno

#include "misc.h"
#include "utils.h"

#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include <string.h>


int main(int argc, char ** argv){
	char filename[256];         		// the name of the file to write data and compare with flexpath
	int  rank=0, size=0;
	MPI_Comm  comm = MPI_COMM_WORLD; 	// required for ADIOS

	int64_t 	adios_handle;   		// the ADIOS file handle
	int retval;

	if (1 < argc){
		usage(argv[0], "Runs writers. It is recommended to run as many writers as readers.");
		return 0;
	}

	// where I will write the data
	strcpy(filename, FILE_NAME);

	// ADIOS initialization
	MPI_Init(&argc, &argv);
	MPI_Comm_rank (comm, &rank);
	MPI_Comm_size (comm, &size);

	if (adios_init(XML_ADIOS_INIT_FILENAME, comm) == 0){
		printf("ERROR: (%d) %s\n", adios_errno, adios_errmsg());
		return -1;
	}

	uint64_t adios_groupsize, adios_totalsize;

	// open with the group name as specified in the xml file
	adios_open( &adios_handle, "scalar", filename, "w", comm);
	adios_groupsize = 4 + 4 + 4;
	retval=adios_group_size (adios_handle, adios_groupsize, &adios_totalsize);
	fprintf(stderr, "Rank=%d adios_group_size(): adios_groupsize=%ld, adios_totalsize=%ld, retval=%d\n",
			rank, adios_groupsize, adios_totalsize, retval);

	// write; don't check errors for simplicity reasons
	adios_write(adios_handle, "size", &size);
	adios_write(adios_handle, "rank", &rank);
	adios_write(adios_handle, "lucky_scalar", &rank);

	fprintf(stderr, "Rank=%d committed write\n", rank);

	// close and finalize the ADIOS and friends
	adios_close(adios_handle);
	adios_finalize(rank);
	MPI_Finalize();

	return 0;
}
