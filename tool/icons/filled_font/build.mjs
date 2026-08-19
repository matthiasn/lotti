import svgtofont from 'svgtofont';
import path from 'path';
await svgtofont({
  src: path.resolve('./svg'),
  dist: path.resolve('./dist'),
  fontName: 'LottiFilled',
  css: false,
  outSVGReact: false,
  outSVGPath: false,
  svgicons2svgfont: { fontHeight: 1000, normalize: true },
});
console.log('done');
