dnl ######################################################################
dnl
dnl Finds PHDF5
dnl
dnl ######################################################################

AC_DEFUN([AC_PHDF5],
[
AC_MSG_NOTICE([=== checking for Parallel HDF5 ===])

AM_CONDITIONAL(HAVE_PHDF5,true)

AC_ARG_WITH([phdf5],
            [  --with-phdf5=<location of PHDF5 installation>],
            [PHDF5_DIR=$withval], [with_phdf5=check])

dnl If --without-phdf5 was given set HAVE_PHDF5 to false and do nothing more
if test "x$with_phdf5" == "xno"; then

   AM_CONDITIONAL(HAVE_PHDF5,false)

else

    dnl allow args --with-phdf5 incdir and --with-phdf5-libdir

    AC_ARG_WITH(phdf5-incdir,
                [  --with-phdf5-incdir=<location of PHDF5 includes>],
                [PHDF5_INCDIR=$withval
                 with_phdf5=detailed])

    AC_ARG_WITH(phdf5-libdir,
                [  --with-phdf5-libdir=<location of PHDF5 library>],
                [PHDF5_LIBDIR=$withval
                 with_phdf5=detailed])

    AC_ARG_WITH(phdf5-libs,
                [  --with-phdf5-libs=<linker flags besides -L<phdf5_libdir>, e.g. -lhdf5 -lhdf5_hl -lz>],
                [PHDF5_LIBS=$withval
                 with_phdf5=detailed])

    ac_use_cray_hdf5=no  dnl will set to yes if we will use CRAY_HDF5_DIR below

    dnl If we know PHDF5_DIR, then we can know PHDF5_INCDIR.
    dnl If we know CRAY_HDF5_DIR, then we leave PHDF5_INCDIR empty.
    dnl If we know HDF5_DIR, then we can know PHDF5_INCDIR.
    dnl We don't overwrite PHDF5_INCDIR.
    if test -z "${PHDF5_INCDIR}"; then
        if test -n "${PHDF5_DIR}"; then
            PHDF5_INCDIR="${PHDF5_DIR}/include";
        elif test -n "${CRAY_HDF5_DIR}"; then
            PHDF5_INCDIR="";
            ac_use_cray_hdf5=yes
        elif test -n "${HDF5_DIR}"; then
            PHDF5_INCDIR="${HDF5_DIR}/include";
        else
            ac_phdf5_ok=no
        fi
    fi

    dnl If we know PHDF5_DIR, then we can know PHDF5_LIBDIR.
    dnl If we know CRAY_HDF5_DIR, then we leave PHDF5_LIBDIR empty.
    dnl If we know HDF5_DIR, then we can know PHDF5_LIBDIR.
    dnl We don't overwrite PHDF5_LIBDIR.
    if test -z "${PHDF5_LIBDIR}"; then
        if test -n "${PHDF5_DIR}"; then
            PHDF5_LIBDIR="${PHDF5_DIR}/lib";
        elif test -n "${CRAY_HDF5_DIR}"; then
            PHDF5_LIBDIR="";
            ac_use_cray_hdf5=yes
        elif test -n "${HDF5_DIR}"; then
            PHDF5_LIBDIR="${HDF5_DIR}/lib";
        else
            ac_phdf5_ok=no
        fi
    fi

    if test -n "${HDF5_CLIB}"; then
    dnl dnl
    dnl dnl Add this elif case if you want phdf5 be discovered automatically
    dnl dnl if HDF5_CLIB is set. It breaks building utils/bp2h5 with --rpath magic!!!
    dnl dnl
            PHDF5_CPPFLAGS="${HDF5_CLIB}"
            dnl    echo " --- HDF5_CLIB was defined. PHDF5_CPPFLAGS=${HDF5_CPPFLAGS}"
    elif test -n "${PHDF5_INCDIR}"; then
            dnl Add "-I" to PHDF5_INCDIR.
            PHDF5_CPPFLAGS="-I${PHDF5_INCDIR}"
    else
            ac_phdf5_ok=no
    fi


    if test -n "${HDF5_CLIB}"; then
    dnl dnl
    dnl dnl Add this elif case if you want phdf5 be discovered automatically
    dnl dnl if HDF5_CLIB is set. It breaks building utils/bp2h5 with --rpath magic!!!
    dnl dnl
             PHDF5_LDFLAGS="${HDF5_CLIB}"
    dnl         dnl    echo " --- HDF5_CLIB was defined. PHDF5_LDFLAGS=${HDF5_CPPFLAGS}"
    elif test -n "${PHDF5_LIBDIR}"; then
            dnl Add "-L" to PHDF5_LIBDIR.
            PHDF5_LDFLAGS="-L${PHDF5_LIBDIR}"
    else
            ac_phdf5_ok=no
    fi


    dnl if hdf5 libs are not defined (and not Cray hdf5 lib), then guess and define it
    if test -z "${PHDF5_LIBS}"; then
        if test "${ac_use_cray_hdf5}" != "yes"; then
            dnl default PHDF5 lib is usually just -lhdf5_hl -lhdf -lz
            PHDF5_LIBS="-lhdf5_hl -lhdf5 -lz"
        fi
    fi

    save_CC="$CC"
    save_CPPFLAGS="$CPPFLAGS"
    save_LIBS="$LIBS"
    save_LDFLAGS="$LDFLAGS"
    LIBS="$LIBS $PHDF5_LIBS"
    LDFLAGS="$LDFLAGS $PHDF5_LDFLAGS"
    CPPFLAGS="$CPPFLAGS $PHDF5_CPPFLAGS"
    CC="$MPICC"

    if test -z "${HAVE_PHDF5_TRUE}"; then
        AC_CHECK_HEADERS(hdf5.h,
        ,
        [if test "x$with_phdf5" != xcheck; then
           AC_MSG_FAILURE( [--with-phdf5 was given, but test for hdf5.h failed])
         fi
         AM_CONDITIONAL(HAVE_PHDF5,false)
        ])
    fi

    if test -z "${HAVE_PHDF5_TRUE}"; then
        AC_MSG_CHECKING([if phdf5 code can be compiled])
        AC_TRY_COMPILE([#include "hdf5.h"],
            [hid_t file_id;
             herr_t status;
#ifdef H5_HAVE_PARALLEL
             file_id = H5Fcreate("a.h5", H5F_ACC_TRUNC, H5P_DEFAULT, H5P_DEFAULT);
             status = H5Fclose(file_id);
#else
             /* This must deliberately fail */
             file_id = THE_HDF5_INSTALLATION_FOUND_IS_NOT_PARALLEL_HDF5
#endif
            ],
            [AC_MSG_RESULT(yes)],
            [AC_MSG_RESULT(no)
         if test "x$with_phdf5" != xcheck; then
               AC_MSG_FAILURE( [--with-phdf5 was given, but compile test failed])
             fi
             AM_CONDITIONAL(HAVE_PHDF5,false)
            ])

        AC_SUBST(PHDF5_LIBS)
        AC_SUBST(PHDF5_LDFLAGS)
        AC_SUBST(PHDF5_CPPFLAGS)
    fi

    LIBS="$save_LIBS"
    LDFLAGS="$save_LDFLAGS"
    CPPFLAGS="$save_CPPFLAGS"
    CC="$save_CC"

    # Finally, execute ACTION-IF-FOUND/ACTION-IF-NOT-FOUND:
    if test -z "${HAVE_PHDF5_TRUE}"; then
            ifelse([$1],,[AC_DEFINE(HAVE_PHDF5,1,[Define if you have PHDF5.])],[$1])
            :
    else
            $2
            :
    fi

fi

])
