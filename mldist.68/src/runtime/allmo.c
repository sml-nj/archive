/* allmo.c:
 *
 * COPYRIGHT (c) 1990 by AT&T Bell Laboratories.
 *
 * This is a stub allmo file for the noshare version.
 */

#include "tags.h"
#include "ml_types.h"

static struct { int tag; char str[16]; } never0 =
    { MAKE_DESC(13, tag_string), "%never match%\0\0\0" };

ML_val_t datalist[4] =
 {  MAKE_DESC(3, tag_record), PTR_CtoML(never0.str), PTR_CtoML(0), MOLST_nil };
