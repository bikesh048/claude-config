---
name: remotion
description: Create programmatic videos using Remotion (React-based video framework). Generate video content from code.
---

# Remotion — Programmatic Video Creation

Build videos programmatically using React components with Remotion.

## When to Use

- Product demos and walkthroughs
- Data visualizations as video
- Automated social media content
- Changelog/release videos
- Tutorial animations

## Setup

```bash
npx create-video@latest my-video
cd my-video
npm start                    # Preview at localhost:3000
```

## Core Concepts

### Composition

```tsx
import { Composition } from 'remotion';

export const RemotionRoot = () => (
  <Composition
    id="MyVideo"
    component={MyVideo}
    durationInFrames={150}   // 5 seconds at 30fps
    fps={30}
    width={1920}
    height={1080}
  />
);
```

### Animation with useCurrentFrame

```tsx
import { useCurrentFrame, interpolate, spring, useVideoConfig } from 'remotion';

const MyVideo = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const opacity = interpolate(frame, [0, 30], [0, 1]);
  const scale = spring({ frame, fps, config: { damping: 10 } });

  return (
    <div style={{ opacity, transform: `scale(${scale})` }}>
      Hello World
    </div>
  );
};
```

### Sequences

```tsx
import { Sequence } from 'remotion';

const MyVideo = () => (
  <>
    <Sequence from={0} durationInFrames={60}>
      <Intro />
    </Sequence>
    <Sequence from={60} durationInFrames={90}>
      <MainContent />
    </Sequence>
  </>
);
```

### Data-Driven Videos

```tsx
const DataVideo = ({ data }: { data: ChartData[] }) => {
  const frame = useCurrentFrame();
  const progress = frame / 150;

  return (
    <div>
      {data.map((item, i) => (
        <Bar
          key={i}
          height={item.value * progress}
          label={item.label}
        />
      ))}
    </div>
  );
};
```

## Rendering

```bash
# Preview
npm start

# Render to MP4
npx remotion render MyVideo out/video.mp4

# Render specific frames
npx remotion render MyVideo out/video.mp4 --frames=0-90

# Render as GIF
npx remotion render MyVideo out/video.gif --image-format=png
```

## Best Practices

- Keep compositions under 60 seconds for social media
- Use `spring()` for natural motion
- Preload assets with `staticFile()` and `delayRender()`
- Test at different resolutions before final render
- Use `<AbsoluteFill>` for full-frame layouts

## Rules

- Always define `durationInFrames`, `fps`, `width`, `height`
- Use `interpolate()` for linear animations, `spring()` for physics-based
- Preload heavy assets to avoid render failures
- Keep React components pure — no side effects in render
