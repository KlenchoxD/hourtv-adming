# HourTV Android Search Progressive Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve the current Search experience while adding a progressively loaded catalog for every available HourTV content type.

**Architecture:** Keep filtering and presentation in `SearchView`, but isolate visible-count and intersection-observer behavior in one reusable hook. Reveal items from the existing `mediaItems` source without duplication; the same mechanism handles the unfiltered catalog and active-query results.

**Tech Stack:** React 19, TypeScript 5.8, Tailwind CSS 4, Vite 6, native `IntersectionObserver`, existing `PosterCard`.

**Spec:** `docs/superpowers/specs/2026-08-22-hourtv-android-profiles-search-catalog-design.md`

## Global Constraints

- Keep the existing search field, recent searches, trends, filters, empty state, and card design.
- Show movies, series, novelas, anime, and every other type present in `mediaItems`.
- Initial batch is 9 items; subsequent batches are 6.
- Never duplicate titles to simulate an infinite catalog.
- Query and filter changes reset the visible count.
- Result counters show the complete match count, not the visible subset.
- No horizontal scroll or exaggerated bottom whitespace.
- Disconnect observers when Search unmounts or the catalog is exhausted.

---

### Task 1: Progressive catalog hook

**Files:**
- Create: `src/hooks/useProgressiveCatalog.ts`

**Interfaces:**
- Produces: `useProgressiveCatalog<T>(items, resetKey, options)` returning `{ visibleItems, hasMore, isLoadingMore, sentinelRef }`.
- Consumes: an already filtered array and a stable reset key from `SearchView`.

- [ ] **Step 1: Run the failing progressive-load behavior test**

Open Search with no query and evaluate the new `Explorar catálogo` grid. Expected before implementation: the section and its `data-catalog-card` elements do not exist.

```js
({
  section: !!document.querySelector('[data-section="catalog"]'),
  visibleCards: document.querySelectorAll('[data-catalog-card]').length,
});
```

- [ ] **Step 2: Implement the hook**

```ts
interface ProgressiveCatalogOptions {
  initialCount?: number;
  batchSize?: number;
  rootMargin?: string;
}

export function useProgressiveCatalog<T>(
  items: T[],
  resetKey: string,
  options: ProgressiveCatalogOptions = {},
) {
  const initialCount = options.initialCount ?? 9;
  const batchSize = options.batchSize ?? 6;
  const [visibleCount, setVisibleCount] = useState(initialCount);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const sentinelRef = useRef<HTMLDivElement | null>(null);
  const hasMore = visibleCount < items.length;

  useEffect(() => setVisibleCount(initialCount), [resetKey, initialCount]);

  useEffect(() => {
    const node = sentinelRef.current;
    if (!node || !hasMore) return;
    const observer = new IntersectionObserver(([entry]) => {
      if (!entry.isIntersecting) return;
      setIsLoadingMore(true);
      requestAnimationFrame(() => {
        setVisibleCount(count => Math.min(count + batchSize, items.length));
        setIsLoadingMore(false);
      });
    }, { rootMargin: options.rootMargin ?? '240px 0px' });
    observer.observe(node);
    return () => observer.disconnect();
  }, [batchSize, hasMore, items.length, options.rootMargin]);

  return {
    visibleItems: items.slice(0, visibleCount),
    hasMore,
    isLoadingMore,
    sentinelRef,
  };
}
```

- [ ] **Step 3: Verify hook safety**

Use a temporary integration in Search and confirm 9 initial cards, 6 additional cards after the sentinel intersects, no count beyond `items.length`, and no observer activity after leaving Search.

- [ ] **Step 4: Save the hook checkpoint**

Save only `src/hooks/useProgressiveCatalog.ts` and the smallest temporary wiring needed for the behavior check.

---

### Task 2: Preserve Search and add `Explorar catálogo`

**Files:**
- Modify: `src/views/SearchView.tsx`

**Interfaces:**
- Consumes: `useProgressiveCatalog`, `mediaItems`, `PosterCard`, `onSelectMedia`, and `onToggleMyList`.
- Produces: the unfiltered progressive catalog section when `query.trim()` is empty.

- [ ] **Step 1: Capture the current Search baseline**

Record a screenshot and DOM assertions for the search field, `Búsquedas recientes`, and `Tendencias`. These elements must remain after the change.

- [ ] **Step 2: Add the catalog hook instance**

```ts
const catalog = useProgressiveCatalog(
  mediaItems,
  'all-catalog',
  { initialCount: 9, batchSize: 6 },
);
```

- [ ] **Step 3: Add the catalog section below existing empty-query content**

Render `Explorar catálogo`, the total title count, and the existing three-column `PosterCard` grid. Add `data-section="catalog"` to the section and `data-catalog-card` to each card wrapper. Preserve existing card props and event handlers.

- [ ] **Step 4: Add a compact end sentinel**

Render the sentinel only while `catalog.hasMore`. Give it `min-h-[24px]`, center a compact HourTV loading indicator only while `catalog.isLoadingMore`, and render nothing when exhausted.

- [ ] **Step 5: Verify visual preservation and progressive loading**

Confirm the existing top sections are unchanged, the catalog starts at 9, adds 6 near the end, does not duplicate IDs, and ends without extra blank space.

- [ ] **Step 6: Save the catalog-section checkpoint**

Save `SearchView.tsx` with the unfiltered catalog integration.

---

### Task 3: Progressive active-query results

**Files:**
- Modify: `src/views/SearchView.tsx`

**Interfaces:**
- Consumes: existing `searchResults`, `filterType`, `query`, and `useProgressiveCatalog`.
- Produces: paginated visual results while preserving the complete result count.

- [ ] **Step 1: Run the failing query-reset test**

Load enough catalog cards to exceed 9, enter a query, and expect the result grid to restart at `min(9, totalMatches)`. Before implementation, all filtered matches render immediately.

- [ ] **Step 2: Add a filtered-result hook instance**

```ts
const searchResetKey = `${query.trim().toLowerCase()}|${filterType}`;
const progressiveResults = useProgressiveCatalog(
  searchResults,
  searchResetKey,
  { initialCount: 9, batchSize: 6 },
);
```

- [ ] **Step 3: Replace only the mapped result array**

Keep the existing heading and use `searchResults.length` for its counter. Replace `searchResults.map(...)` with `progressiveResults.visibleItems.map(...)`. Add the same compact sentinel only when `progressiveResults.hasMore`.

- [ ] **Step 4: Verify resets and filters**

Test a broad query, scroll to load more, change the query, and confirm visible results reset. Repeat for `Todos`, `Películas`, `Series`, and `4K`; the counter must always show the full match total.

- [ ] **Step 5: Save the query-pagination checkpoint**

Save only `SearchView.tsx`.

---

### Task 4: Search regression and acceptance QA

**Files:**
- Verify only; modify the smallest owning file if a test fails.

**Interfaces:**
- Consumes the complete progressive Search implementation.
- Produces a final evidence table.

- [ ] **Step 1: Verify the unchanged upper experience**

Confirm search input, recent searches, trending keywords, filter chips, loading skeleton, and empty-result state remain functional.

- [ ] **Step 2: Verify unfiltered catalog loading**

Count unique media IDs after each load: 9, then 15, then `min(previous + 6, total)`. Confirm no duplicates and no sentinel after exhaustion.

- [ ] **Step 3: Verify all content categories**

Confirm the catalog includes every content type and genre available in `mediaItems`, including series and novela-tagged items when present.

- [ ] **Step 4: Verify navigation and scroll**

Open a catalog card in Details, return to Search, and confirm Search remains usable. Scroll to the end and measure bottom whitespace against the established Android pattern; reject gaps over 48 px above Bottom Navigation.

- [ ] **Step 5: Run final runtime checks**

Confirm no compile overlay, no console errors, no horizontal overflow, card targets remain at least 48 px, and Home, TV, Library, Details, Player, and Profile remain unchanged. Leave Search visible at a partially loaded catalog for review.

