/* Copyright (C) 1999-2006 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 * Copyright (C) 1997-2000 NEC Research Institute.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 */

#if (defined (MLTON_GC_INTERNAL_FUNCS))
#endif /* (defined (MLTON_GC_INTERNAL_FUNCS)) */

#if (defined (MLTON_GC_INTERNAL_BASIS))

PRIVATE void GC_saveWorld (GC_state s, NullString8_t fileName);
/* TRUE = success, FALSE = failure */
PRIVATE C_Errno_t(Bool_t) GC_getSaveWorldStatus (GC_state s);

#endif /* (defined (MLTON_GC_INTERNAL_BASIS)) */
