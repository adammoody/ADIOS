dnl ######################################################################
dnl
dnl Finds SCR
dnl
dnl ######################################################################

AC_DEFUN([AC_SCR],
[
AC_MSG_NOTICE([=== checking for SCR ===])

AM_CONDITIONAL(HAVE_SCR,true)

AC_ARG_WITH(scr,
            [  --with-scr=<location of SCR installation>],
            [SCR_DIR=$withval], [with_scr=check])

dnl If --without-scr was given set HAVE_SCR to false and do nothing more
if test "x$with_scr" == "xno"; then

   AM_CONDITIONAL(HAVE_SCR,false)

else

    dnl allow args --with-scr incdir and --with-scr-libdir
    AC_ARG_WITH(scr-incdir,
                [  --with-scr-incdir=<location of SCR includes>],
                [SCR_INCDIR=$withval
                 with_scr=detailed])
    
    AC_ARG_WITH(scr-libdir,
                [  --with-scr-libdir=<location of SCR library>],
                [SCR_LIBDIR=$withval
                 with_scr=detailed])
    
    AC_ARG_WITH(scr-libs,
                [  --with-scr-libs=<linker flags besides -L<scr_libdir>, e.g. -lscr>],
                [SCR_LIBS=$withval
                 with_scr=detailed])
    
    dnl If we know SCR_DIR, then we can know SCR_INCDIR.
    dnl We may have SCR denoting the dir (e.g. on ewok BUT on franklin it contains all flags)
    dnl We don't overwrite SCR_INCDIR.
    if test -z "${SCR_INCDIR}"; then
        if test -n "${SCR_DIR}"; then
            SCR_INCDIR="${SCR_DIR}/include";
        elif test -n "${SCR}" -a -d "${SCR}"; then
            SCR_INCDIR="${SCR}/include"
        fi
    fi
    
    dnl If we know SCR_DIR, then we can know SCR_LIBDIR.
    dnl If we know CRAY_SCR_DIR, then we leave SCR_LIBDIR empty.
    dnl We may have SCR denoting the dir (e.g. on ewok BUT on franklin it contains all flags)
    dnl We don't overwrite SCR_LIBDIR.
    if test -z "${SCR_LIBDIR}"; then
        if test -n "${SCR_DIR}"; then
            SCR_LIBDIR="${SCR_DIR}/lib";
        elif test -n "${SCR}" -a -d "${SCR}"; then
            SCR_LIBDIR="${SCR}/lib"
        fi
    fi
    
    dnl Add "-I" to SCR_INCDIR.
    if test -n "${SCR_INCDIR}"; then
            SCR_CPPFLAGS="-I${SCR_INCDIR}"
    else
            ac_scr_ok=no
    fi

    dnl Add "-L" to SCR_LIBDIR.
    if test -n "${SCR_LIBDIR}"; then
            SCR_LDFLAGS="-L${SCR_LIBDIR}"
    else
            ac_scr_ok=no
    fi

    dnl if scr libs are not defined, then guess and define it
    if test -z "${SCR_LIBS}"; then
        SCR_LIBS="-lscr -lscr_base"
    fi

    save_CPPFLAGS="$CPPFLAGS"
    save_LIBS="$LIBS"
    save_LDFLAGS="$LDFLAGS"
    LIBS="$LIBS $SCR_LDFLAGS"
    LDFLAGS="$LDFLAGS $SCR_LDFLAGS"
    CPPFLAGS="$CPPFLAGS $SCR_CPPFLAGS"
    
    if test -z "${HAVE_SCR_TRUE}"; then
        AC_CHECK_HEADERS(scr.h,
           ,
           [if test "x$with_scr" != xcheck; then
              AC_MSG_FAILURE( [--with-scr was given, but test for scr.h failed])
            fi
            AM_CONDITIONAL(HAVE_SCR,false)])
    fi
    
    if test -z "${HAVE_SCR_TRUE}"; then
        AC_MSG_CHECKING([if scr code can be compiled])
#        AC_TRY_COMPILE([#include "scr.h"],
#            [int ncid;
#             nc_create("a.nc", NC_CLOBBER, &ncid);
#             nc_close(ncid);
#            ],
#            [AC_MSG_RESULT(yes)],
#            [AC_MSG_RESULT(no)
#             if test "x$with_scr" != xcheck; then
#                 AC_MSG_FAILURE( [--with-scr was given, but compile test failed])
#             fi
#             AM_CONDITIONAL(HAVE_SCR,false)
#            ])
   
       AC_SUBST(SCR_LIBS)
       AC_SUBST(SCR_LDFLAGS)
       AC_SUBST(SCR_CPPFLAGS)
    fi
    
    LIBS="$save_LIBS"
    LDFLAGS="$save_LDFLAGS"
    CPPFLAGS="$save_CPPFLAGS"
    
    # Finally, execute ACTION-IF-FOUND/ACTION-IF-NOT-FOUND:
    if test -z "${HAVE_SCR_TRUE}"; then
            ifelse([$1],,[AC_DEFINE(HAVE_SCR,1,[Define if you have SCR.])],[$1])
            :
    else
            $2
            :
    fi

fi

])
