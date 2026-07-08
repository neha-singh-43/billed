# Sprite Engine Documentation

This document describes the design, configuration, and implementation of the animated pet/mascot sprite engine reconstructed in the `billed` app.

---

## 1. Spritesheet Specifications
The engine uses standard Codex-style character assets. Every spritesheet matches the following dimensions and structure:
*   **Dimensions**: `1536 x 1872` pixels
*   **Grid layout**: 8 columns (X axis) by 9 rows (Y axis)
*   **Cell dimensions**: `192 x 208` pixels per frame

---

## 2. Frame coordinates & Background position
To render a specific frame dynamically without cutting individual image files, the engine sets the spritesheet as the `background-image` of a single `div` element and updates the `background-position` CSS property using percentage calculations:

$$\text{X Percentage} = \frac{\text{columnIndex}}{7} \times 100\%$$
$$\text{Y Percentage} = \frac{\text{rowIndex}}{8} \times 100\%$$

In React/HTML styling, this translates to:
```typescript
const xPercentage = (frame.columnIndex / 7) * 100;
const yPercentage = (frame.rowIndex / 8) * 100;

const style = {
  backgroundImage: `url(${spritesheet})`,
  backgroundPosition: `${xPercentage}% ${yPercentage}%`,
  backgroundSize: "800% 900%",
};
```
*Note: `background-size: 800% 900%` stretches the spritesheet background to span exactly 8 times the width and 9 times the height of the container, aligning perfectly with a single frame's aspect ratio.*

---

## 3. Animation State Mapping
The table below specifies the rows (0-indexed) mapping to each animation state, along with the frame columns and frame-by-frame durations:

| State | Row Index | Frame Count | Column Index & Frame Durations (ms) |
| :--- | :--- | :--- | :--- |
| `idle` | `0` | 6 | `Col 0: 280ms`, `Col 1: 110ms`, `Col 2: 110ms`, `Col 3: 140ms`, `Col 4: 140ms`, `Col 5: 320ms` |
| `running-right` | `1` | 8 | Columns 0-7: `120ms` per frame (last frame is `220ms`) |
| `running-left` | `2` | 8 | Columns 0-7: `120ms` per frame (last frame is `220ms`) |
| `waving` | `3` | 4 | Columns 0-3: `140ms` per frame (last frame is `280ms`) |
| `jumping` | `4` | 5 | Columns 0-4: `140ms` per frame (last frame is `280ms`) |
| `failed` | `5` | 8 | Columns 0-7: `140ms` per frame (last frame is `240ms`) |
| `waiting` | `6` | 6 | Columns 0-5: `150ms` per frame (last frame is `260ms`) |
| `running` | `7` | 6 | Columns 0-5: `120ms` per frame (last frame is `220ms`) |
| `review` | `8` | 6 | Columns 0-5: `150ms` per frame (last frame is `280ms`) |

---

## 4. Animation Timing & Playback Logic
The engine uses React `useEffect` hooks paired with recursive `setTimeout` callbacks to ensure tick-perfect playback.

### State Transitions & Sequences
When the active pet transitions to a specific action (e.g. `jumping` or `waving` when clicked), the engine:
1. Loops the action frames exactly **three times** consecutively.
2. Appends the default `idle` frames chain to the end of the action array.
3. Once the 3-cycle action finishes, the playback loop resets to the start of the `idle` sequence, creating a fluid transition back to resting:

```typescript
useEffect(() => {
  let activeFrames = rowFrames.idle;
  let loopStart = 0;

  if (state === "jumping") {
    const repeated = [...rowFrames.jumping, ...rowFrames.jumping, ...rowFrames.jumping];
    activeFrames = [...repeated, ...rowFrames.idle];
    loopStart = repeated.length;
  }
  // Playback...
}, [state]);
```
