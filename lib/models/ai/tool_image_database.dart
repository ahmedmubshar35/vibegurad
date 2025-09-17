import '../../enums/tool_type.dart';

class ToolImageDatabase {
  // Tool recognition patterns and keywords
  static const Map<ToolType, ToolImageEntry> _database = {
    ToolType.drill: ToolImageEntry(
      toolType: ToolType.drill,
      keywords: [
        'drill', 'drilling', 'hole', 'bit', 'chuck', 'trigger', 'battery',
        'cordless drill', 'power drill', 'impact drill', 'hammer drill',
        'screw', 'rotation', 'torque', 'motor', 'clutch'
      ],
      visualFeatures: [
        'cylindrical body', 'pistol grip', 'trigger mechanism',
        'chuck at front', 'battery pack', 'LED light', 'belt clip'
      ],
      brandColors: {
        'Bosch': ['blue', 'black', 'professional'],
        'Makita': ['teal', 'turquoise', 'black'],
        'DeWalt': ['yellow', 'black'],
        'Milwaukee': ['red', 'black'],
        'Ryobi': ['green', 'black'],
        'Black+Decker': ['orange', 'black'],
      },
      commonModels: [
        'DCD', 'GSB', 'M18', 'P207', 'LDX120', 'CD18', 'DHP',
        '18V', '12V', '20V', 'MAX', 'ONE+', 'FUEL'
      ],
      vibrationLevels: {
        'low': 1.5,
        'medium': 3.5,
        'high': 8.0,
      },
    ),
    
    ToolType.grinder: ToolImageEntry(
      toolType: ToolType.grinder,
      keywords: [
        'grinder', 'grinding', 'disc', 'wheel', 'angle grinder', 'cut-off',
        'polishing', 'metal cutting', 'stone cutting', 'abrasive',
        'spindle', 'guard', 'side handle'
      ],
      visualFeatures: [
        'disc guard', 'side handle', 'spindle lock', 'venting slots',
        'compact body', 'power switch', 'cord strain relief'
      ],
      brandColors: {
        'Bosch': ['blue', 'black', 'grey'],
        'Makita': ['teal', 'black'],
        'DeWalt': ['yellow', 'black'],
        'Milwaukee': ['red', 'black'],
        'Metabo': ['green', 'black'],
        'Hitachi': ['green', 'black'],
      },
      commonModels: [
        'GWS', 'GA', 'DCG', '2780', 'AG', 'DWE', 'WE',
        '115mm', '125mm', '230mm', '4.5"', '5"', '9"'
      ],
      vibrationLevels: {
        'low': 3.0,
        'medium': 7.5,
        'high': 15.0,
      },
    ),
    
    ToolType.sander: ToolImageEntry(
      toolType: ToolType.sander,
      keywords: [
        'sander', 'sanding', 'sandpaper', 'orbital', 'belt sander',
        'palm sander', 'finish', 'smooth', 'wood finishing',
        'velcro', 'dust extraction', 'oscillating'
      ],
      visualFeatures: [
        'sanding pad', 'dust port', 'velcro base', 'ergonomic grip',
        'variable speed', 'paper clamps', 'dust bag'
      ],
      brandColors: {
        'Bosch': ['green', 'black'],
        'Makita': ['teal', 'black'],
        'DeWalt': ['yellow', 'black'],
        'Festool': ['green', 'black'],
        'Porter-Cable': ['black', 'grey'],
      },
      commonModels: [
        'ROS', 'BO', 'DWE', 'ETS', 'PCE', 'GSS', 'PEX',
        '125mm', '150mm', '5"', '6"', 'orbital', 'sheet'
      ],
      vibrationLevels: {
        'low': 2.0,
        'medium': 4.5,
        'high': 9.0,
      },
    ),
    
    ToolType.saw: ToolImageEntry(
      toolType: ToolType.saw,
      keywords: [
        'saw', 'cutting', 'blade', 'circular saw', 'jigsaw', 'reciprocating',
        'wood cutting', 'metal cutting', 'miter saw', 'crosscut',
        'rip cut', 'depth adjustment', 'bevel'
      ],
      visualFeatures: [
        'circular blade', 'blade guard', 'base plate', 'depth adjustment',
        'bevel adjustment', 'fence', 'dust port', 'laser guide'
      ],
      brandColors: {
        'Bosch': ['blue', 'black'],
        'Makita': ['teal', 'black'],
        'DeWalt': ['yellow', 'black'],
        'Milwaukee': ['red', 'black'],
        'Skilsaw': ['silver', 'black'],
      },
      commonModels: [
        'GKS', 'DHS', 'DWE', 'M18', 'SPT', 'CS', '5007',
        '165mm', '184mm', '190mm', '235mm', '6.5"', '7.25"'
      ],
      vibrationLevels: {
        'low': 2.5,
        'medium': 5.0,
        'high': 10.0,
      },
    ),
    
    ToolType.hammer: ToolImageEntry(
      toolType: ToolType.hammer,
      keywords: [
        'hammer', 'impact', 'driver', 'impact driver', 'impact wrench',
        'pneumatic', 'air hammer', 'demolition hammer',
        'rotary hammer', 'SDS', 'chisel', 'percussion'
      ],
      visualFeatures: [
        'impact mechanism', 'hex chuck', 'anvil', 'hammer body',
        'side handle', 'depth rod', 'mode selector', 'SDS chuck'
      ],
      brandColors: {
        'Bosch': ['blue', 'black'],
        'Makita': ['teal', 'black'],
        'DeWalt': ['yellow', 'black'],
        'Milwaukee': ['red', 'black'],
        'Hilti': ['red', 'grey'],
      },
      commonModels: [
        'GBH', 'DHR', 'DCF', '2767', 'M18', 'GDR', 'SDS',
        'RH', 'HR', 'FUEL', 'POWERSTATE', 'XPT'
      ],
      vibrationLevels: {
        'low': 5.0,
        'medium': 12.0,
        'high': 25.0,
      },
    ),
    
    ToolType.nailer: ToolImageEntry(
      toolType: ToolType.nailer,
      keywords: [
        'nailer', 'nail gun', 'stapler', 'nailgun', 'brad nailer',
        'finish nailer', 'framing nailer', 'pneumatic nailer',
        'cordless nailer', 'air nailer', 'fastener'
      ],
      visualFeatures: [
        'magazine', 'nose piece', 'trigger', 'depth adjustment',
        'safety tip', 'air fitting', 'battery pack', 'exhaust port'
      ],
      brandColors: {
        'Paslode': ['orange', 'black'],
        'Makita': ['teal', 'black'],
        'DeWalt': ['yellow', 'black'],
        'Milwaukee': ['red', 'black'],
        'Bostitch': ['yellow', 'black'],
      },
      commonModels: [
        'AF', 'DCN', 'M18', 'SB', 'BTN', '18GA', '16GA',
        '15GA', '23GA', 'CF', 'PN', 'GNT'
      ],
      vibrationLevels: {
        'low': 1.0,
        'medium': 2.5,
        'high': 5.0,
      },
    ),
  };
  
  // Get tool entry by type
  static ToolImageEntry? getEntry(ToolType toolType) {
    return _database[toolType];
  }
  
  // Get all entries
  static Map<ToolType, ToolImageEntry> getAllEntries() {
    return Map.from(_database);
  }
  
  // Search for tools by keyword
  static List<ToolType> searchByKeyword(String keyword) {
    final results = <ToolType>[];
    final searchTerm = keyword.toLowerCase();
    
    for (final entry in _database.entries) {
      final toolEntry = entry.value;
      
      // Check keywords
      if (toolEntry.keywords.any((k) => k.toLowerCase().contains(searchTerm))) {
        results.add(entry.key);
        continue;
      }
      
      // Check visual features
      if (toolEntry.visualFeatures.any((f) => f.toLowerCase().contains(searchTerm))) {
        results.add(entry.key);
        continue;
      }
      
      // Check brand colors
      for (final brandEntry in toolEntry.brandColors.entries) {
        if (brandEntry.key.toLowerCase().contains(searchTerm) ||
            brandEntry.value.any((color) => color.toLowerCase().contains(searchTerm))) {
          results.add(entry.key);
          break;
        }
      }
    }
    
    return results;
  }
  
  // Get brand color patterns for recognition
  static List<String> getBrandColors(String brand) {
    final colors = <String>[];
    
    for (final entry in _database.values) {
      if (entry.brandColors.containsKey(brand)) {
        colors.addAll(entry.brandColors[brand]!);
      }
    }
    
    return colors.toSet().toList();
  }
  
  // Get expected vibration level for tool type
  static double getExpectedVibration(ToolType toolType, String level) {
    final entry = _database[toolType];
    if (entry != null && entry.vibrationLevels.containsKey(level)) {
      return entry.vibrationLevels[level]!;
    }
    return 0.0;
  }
  
  // Calculate tool recognition confidence based on multiple factors
  static double calculateConfidence(
    ToolType detectedType,
    String detectedBrand,
    List<String> detectedKeywords,
    List<String> detectedColors,
  ) {
    final entry = _database[detectedType];
    if (entry == null) return 0.0;
    
    double confidence = 0.0;
    double totalWeight = 0.0;
    
    // Keyword matching (40% weight)
    double keywordScore = 0.0;
    for (final keyword in detectedKeywords) {
      if (entry.keywords.any((k) => k.toLowerCase().contains(keyword.toLowerCase()))) {
        keywordScore += 1.0;
      }
    }
    keywordScore = keywordScore / entry.keywords.length;
    confidence += keywordScore * 0.4;
    totalWeight += 0.4;
    
    // Brand matching (30% weight)
    double brandScore = 0.0;
    if (entry.brandColors.containsKey(detectedBrand)) {
      brandScore = 1.0;
      
      // Brand color matching bonus
      final brandColors = entry.brandColors[detectedBrand]!;
      double colorScore = 0.0;
      for (final color in detectedColors) {
        if (brandColors.any((bc) => bc.toLowerCase().contains(color.toLowerCase()))) {
          colorScore += 1.0;
        }
      }
      colorScore = colorScore / brandColors.length;
      brandScore += colorScore * 0.5; // Bonus for color match
    }
    confidence += brandScore * 0.3;
    totalWeight += 0.3;
    
    // Visual features matching (30% weight)  
    double featureScore = 0.0;
    for (final keyword in detectedKeywords) {
      if (entry.visualFeatures.any((f) => f.toLowerCase().contains(keyword.toLowerCase()))) {
        featureScore += 1.0;
      }
    }
    featureScore = featureScore / entry.visualFeatures.length;
    confidence += featureScore * 0.3;
    totalWeight += 0.3;
    
    return totalWeight > 0 ? confidence / totalWeight : 0.0;
  }
}

class ToolImageEntry {
  final ToolType toolType;
  final List<String> keywords;
  final List<String> visualFeatures;
  final Map<String, List<String>> brandColors;
  final List<String> commonModels;
  final Map<String, double> vibrationLevels;
  
  const ToolImageEntry({
    required this.toolType,
    required this.keywords,
    required this.visualFeatures,
    required this.brandColors,
    required this.commonModels,
    required this.vibrationLevels,
  });
  
  // Check if a label matches this tool type
  bool matchesLabel(String label) {
    final labelLower = label.toLowerCase();
    
    return keywords.any((keyword) => labelLower.contains(keyword.toLowerCase())) ||
           visualFeatures.any((feature) => labelLower.contains(feature.toLowerCase())) ||
           commonModels.any((model) => labelLower.contains(model.toLowerCase()));
  }
  
  // Get brand from detected colors
  String? getBrandFromColors(List<String> detectedColors) {
    for (final brandEntry in brandColors.entries) {
      final brandName = brandEntry.key;
      final brandColorList = brandEntry.value;
      
      for (final detectedColor in detectedColors) {
        if (brandColorList.any((bc) => bc.toLowerCase().contains(detectedColor.toLowerCase()))) {
          return brandName;
        }
      }
    }
    return null;
  }
  
  // Get vibration category based on level
  String getVibrationCategory(double vibrationLevel) {
    if (vibrationLevel <= vibrationLevels['low']!) {
      return 'Low';
    } else if (vibrationLevel <= vibrationLevels['medium']!) {
      return 'Medium';
    } else {
      return 'High';
    }
  }
  
  // Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'toolType': toolType.toString(),
      'keywords': keywords,
      'visualFeatures': visualFeatures,
      'brandColors': brandColors,
      'commonModels': commonModels,
      'vibrationLevels': vibrationLevels,
    };
  }
}