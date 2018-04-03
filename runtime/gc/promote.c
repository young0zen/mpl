/* Copyright (C) 2017 Adrien Guatto.
 *
 * MLton is released under a BSD-style license.
 * See the file MLton-LICENSE for details.
 */

pointer HM_Promote(GC_state s,
                   struct HM_ChunkInfo *dst_chunk,
                   pointer src) {
    dst_chunk = HM_getChunkHeadChunk(dst_chunk);
    struct HM_ChunkInfo *src_chunk =
        HM_getObjptrLevelHeadChunk(s, pointerToObjptr(src, s->heap->start));
    void *tgtChunkList = HM_getChunkHeadChunk(dst_chunk);
    struct HM_HierarchicalHeap *dst_hh =
        dst_chunk->split.levelHead.containingHH;
    bool needToUpdateLCS = false;

    struct HM_HierarchicalHeap *current_hh = getHierarchicalHeapCurrent(s);
    if (dst_chunk->level >= HM_HH_getLowestPrivateLevel(s, current_hh)) {
      assert (dst_hh == current_hh);
      needToUpdateLCS = true;
      dst_hh->locallyCollectibleSize -=
          HM_getChunkInfo(tgtChunkList)->split.levelHead.size;
    }

    LOG(LM_HH_PROMOTION, LL_INFO,
        "Promoting src %p to chunk list %p",
        (void *)src, (void *)dst_chunk);

    Trace2(EVENT_PROMOTION_ENTER, (EventInt)src, (EventInt)dst_chunk);
    TraceResetCopy(); /* Reset copy events. */

    /* AG_NOTE is this needed? */
    getStackCurrent(s)->used = sizeofGCStateCurrentStackUsed (s);
    getThreadCurrent(s)->exnStack = s->exnStack;

    assert (!dst_hh->newLevelList);

    if (dst_hh->lastAllocatedChunk == HM_getChunkListLastChunk(tgtChunkList)) {
        /* chunk in use, so append a new one to it */
        HM_allocateChunk(tgtChunkList, GC_HEAP_LIMIT_SLOP);
        LOG(LM_HH_PROMOTION, LL_DEBUG,
            "Chunk %p at level %u in use, so appending new chunk",
            dst_hh->lastAllocatedChunk,
            dst_chunk->level);
    }

    struct ForwardHHObjptrArgs forwardHHObjptrArgs = {
        .hh = dst_hh,
        .minLevel = dst_chunk->level + 1,
        .maxLevel = src_chunk->level,
        .tgtChunkList = tgtChunkList,
        .bytesCopied = 0,
        .objectsCopied = 0,
        .stacksCopied = 0
    };

    LOG(LM_HH_PROMOTION, LL_DEBUG,
        "promoting %p to chunk %p:\n"
        "  scope is %u -> %u\n",
        (void *)src,
        (void *)dst_chunk,
        forwardHHObjptrArgs.minLevel,
        forwardHHObjptrArgs.maxLevel);

    objptr srcobj = pointerToObjptr(src, s->heap->start);

    LOG(LM_HH_PROMOTION, LL_DEBUG, "START src copy");

    void *lastChunk = HM_getChunkListLastChunk(tgtChunkList);
    pointer start = HM_getChunkFrontier(lastChunk);

    forwardHHObjptr(s, &srcobj, &forwardHHObjptrArgs);

    if (lastChunk != HM_getChunkListLastChunk(tgtChunkList)) {
        start = HM_getChunkStart(HM_getChunkListLastChunk(tgtChunkList));
    }

    LOG(LM_HH_PROMOTION, LL_DEBUG, "START copy loop at %p", (void *)start);

    HM_forwardHHObjptrsInChunkList(
        s,
        start,
        trueObjptrPredicate,
        NULL,
        &forwardHHObjptrArgs);

    /* We need to ensure some invariants.

       1/ Reset the to-space level list.

       2/ Reset the cached pointer from the from-space chunk list to the
       to-space chunk list.

       3/ Update locallyCollectibleSize if we have been promoting to a locally
       collectible level.
    */

    dst_hh->newLevelList = NULL;

    assert (forwardHHObjptrArgs.tgtChunkList);
    assert (!HM_getChunkInfo(forwardHHObjptrArgs.tgtChunkList)->
            split.levelHead.toChunkList);

    if (needToUpdateLCS) {
        dst_hh->locallyCollectibleSize +=
            HM_getChunkInfo(tgtChunkList)->split.levelHead.size;
    }

    assertInvariants(s, dst_hh, LIVE);

    s->cumulativeStatistics->bytesPromoted += forwardHHObjptrArgs.bytesCopied;

    /* Exit. */

    TraceResetCopy();
    Trace0(EVENT_PROMOTION_LEAVE);

    pointer res = objptrToPointer(srcobj, s->heap->start);

    LOG(LM_HH_PROMOTION, LL_DEBUG,
        "Promoted src %p to replica %p",
        (void *)src, (void *)res);

    Trace2(EVENT_PROMOTION, (EventInt)(void *)src, (EventInt)(void *)res);

    return res;
}