/* Copyright (C) 2018-2021 Sam Westrick
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 */

void HM_remember(HM_chunkList remSet, HM_remembered remElem) {
  HM_storeInchunkList(remSet, (void*)remElem, sizeof(struct HM_remembered));
}

void HM_rememberAtLevel(HM_HierarchicalHeap hh, HM_remembered remElem) {
  assert(hh != NULL);
  HM_remember(HM_HH_getRemSet(hh), remElem);
}

void HM_foreachRemembered(
  GC_state s,
  HM_chunkList remSet,
  HM_foreachDownptrClosure f)
{
  assert(remSet != NULL);
  HM_chunk chunk = HM_getChunkListFirstChunk(remSet);
  while (chunk != NULL) {
    pointer p = HM_getChunkStart(chunk);
    pointer frontier = HM_getChunkFrontier(chunk);
    while (p < frontier) {
      f->fun(s, (HM_remembered)p, f->env);
      p += sizeof(struct HM_remembered);
    }
    chunk = chunk->nextChunk;
  }
}

size_t HM_numRemembered(HM_chunkList remSet) {
  assert(remSet != NULL);
  size_t count = 0;
  HM_chunk chunk = HM_getChunkListFirstChunk(remSet);
  while (chunk != NULL) {
    pointer p = HM_getChunkStart(chunk);
    pointer frontier = HM_getChunkFrontier(chunk);
    count += (size_t)((frontier - p)) / sizeof(struct HM_remembered);
    chunk = chunk->nextChunk;
  }

  return count;
}
