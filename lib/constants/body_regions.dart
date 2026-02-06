/// 身体区域枚举（简化区域）
enum BodyRegion {
  head,      // 头部
  neck,      // 颈部
  shoulder,  // 肩部
  chest,     // 胸部
  abdomen,   // 腹部
  back,      // 背部
  hip,       // 臀部
  thigh,     // 大腿
  calf,      // 小腿
}

/// 肌肉名称到身体区域的映射
const Map<String, BodyRegion> MUSCLE_TO_REGION = {
  '颈部': BodyRegion.neck,
  '斜方肌': BodyRegion.shoulder,
  '菱形肌': BodyRegion.back,
  '胸椎': BodyRegion.back,
  '腹斜肌': BodyRegion.abdomen,
  '腹横肌': BodyRegion.abdomen,
  '腹直肌': BodyRegion.abdomen,
  '膈肌': BodyRegion.abdomen,
  '股四头肌': BodyRegion.thigh,
  '臀大肌': BodyRegion.hip,
  '腓肠肌': BodyRegion.calf,
  '比目鱼肌': BodyRegion.calf,
};

/// 疼痛部位选项（与 onboarding 一致）
const List<Map<String, String>> PAIN_LOCATION_OPTIONS = [
  {'value': '颈部', 'label': '颈部'},
  {'value': '肩部', 'label': '肩部'},
  {'value': '腰部', 'label': '腰部'},
  {'value': '膝盖', 'label': '膝盖'},
  {'value': '手腕', 'label': '手腕'},
];

/// 身体限制到身体区域的映射（UserProfile.limitations 使用）
const Map<String, BodyRegion> LIMITATION_TO_REGION = {
  'waist': BodyRegion.abdomen,      // 腰肌劳损 -> 腹部
  'knee': BodyRegion.thigh,         // 膝盖不适 -> 大腿（膝盖区域）
  'shoulder': BodyRegion.shoulder,  // 肩颈僵硬 -> 肩部
  'wrist': BodyRegion.shoulder,     // 手腕不适 -> 肩部区域
};

/// 疼痛部位名称到身体区域的映射
const Map<String, BodyRegion> PAIN_LOCATION_TO_REGION = {
  '颈部': BodyRegion.neck,
  '肩部': BodyRegion.shoulder,
  '腰部': BodyRegion.abdomen,
  '膝盖': BodyRegion.thigh,
  '手腕': BodyRegion.shoulder,
};

/// BodyRegion 的中文显示名称
const Map<BodyRegion, String> BODY_REGION_NAMES = {
  BodyRegion.head: '头部',
  BodyRegion.neck: '颈部',
  BodyRegion.shoulder: '肩部',
  BodyRegion.chest: '胸部',
  BodyRegion.abdomen: '腹部',
  BodyRegion.back: '背部',
  BodyRegion.hip: '臀部',
  BodyRegion.thigh: '大腿',
  BodyRegion.calf: '小腿',
};
