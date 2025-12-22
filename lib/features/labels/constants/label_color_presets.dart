class LabelColorPreset {
  const LabelColorPreset({
    required this.name,
    required this.hex,
  });

  final String name;
  final String hex;
}

const List<LabelColorPreset> labelColorPresets = [
  LabelColorPreset(name: 'Ocean Blue', hex: '#0066CC'),
  LabelColorPreset(name: 'Emerald', hex: '#1B998B'),
  LabelColorPreset(name: 'Coral', hex: '#F25F5C'),
  LabelColorPreset(name: 'Sunset', hex: '#FF8C42'),
  LabelColorPreset(name: 'Slate', hex: '#4F5D75'),
  LabelColorPreset(name: 'Lavender', hex: '#7E57C2'),
  LabelColorPreset(name: 'Teal Glow', hex: '#2EC4B6'),
  LabelColorPreset(name: 'Crimson', hex: '#E63946'),
  LabelColorPreset(name: 'Amethyst', hex: '#8338EC'),
  LabelColorPreset(name: 'Goldenrod', hex: '#FFB400'),
  LabelColorPreset(name: 'Skyline', hex: '#3A86FF'),
  LabelColorPreset(name: 'Magenta', hex: '#FF006E'),
  LabelColorPreset(name: 'Mint', hex: '#06D6A0'),
  LabelColorPreset(name: 'Deep Sea', hex: '#118AB2'),
  LabelColorPreset(name: 'Charcoal', hex: '#2D3142'),
  LabelColorPreset(name: 'Rosewood', hex: '#9B5DE5'),
];
