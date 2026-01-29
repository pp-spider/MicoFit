import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/weekly_data.dart';

/// 示例训练计划
WorkoutPlan getSampleWorkoutPlan() {
  return WorkoutPlan(
    id: '1',
    title: '今日微动',
    subtitle: 'Tuesday Flow',
    totalDuration: 12,
    scene: '办公室场景',
    rpe: 6,
    aiNote: '因你昨晚睡眠<6小时，已移除跳跃动作，降低心肺压力',
    modules: [
      WorkoutModule(
        id: 'm1',
        name: '工位肩颈解放',
        duration: 3,
        exercises: [
          Exercise(
            id: 'e1',
            name: '颈部侧拉伸',
            duration: 45,
            description: '缓解颈部僵硬，改善血液循环',
            steps: [
              '坐稳椅面1/3处，脊柱中立',
              '一手扶头侧向轻拉至极限',
              '感受对侧颈部拉伸感',
              '保持自然呼吸，不要憋气',
            ],
            tips: '避免耸肩，动作轻缓',
            breathing: '自然呼吸，不要憋气',
            image: 'assets/exercises/exercise-neck.png',
            targetMuscles: ['颈部', '斜方肌'],
          ),
          Exercise(
            id: 'e2',
            name: '肩胛激活',
            duration: 45,
            description: '激活肩胛周围肌肉',
            steps: [
              '双肩自然下沉',
              '肩胛骨向后夹紧',
              '保持3秒后放松',
              '重复8-10次',
            ],
            tips: '不要耸肩，感受肩胛骨收缩',
            breathing: '夹紧时呼气，放松时吸气',
            image: 'assets/exercises/exercise-neck.png',
            targetMuscles: ['斜方肌', '菱形肌'],
          ),
          Exercise(
            id: 'e3',
            name: '胸椎旋转',
            duration: 60,
            description: '改善胸椎灵活性',
            steps: [
              '坐姿，双手抱胸',
              '缓慢向一侧旋转上半身',
              '保持2秒后回正',
              '左右交替进行',
            ],
            tips: '骨盆保持稳定',
            breathing: '旋转时呼气，回正时吸气',
            image: 'assets/exercises/exercise-neck.png',
            targetMuscles: ['胸椎', '腹斜肌'],
          ),
        ],
      ),
      WorkoutModule(
        id: 'm2',
        name: '核心稳定激活',
        duration: 4,
        exercises: [
          Exercise(
            id: 'e4',
            name: '腹式呼吸',
            duration: 60,
            description: '激活深层核心肌群',
            steps: [
              '一手放胸口，一手放腹部',
              '吸气时腹部鼓起',
              '呼气时腹部收缩',
              '胸口保持相对稳定',
            ],
            tips: '专注于腹部起伏',
            breathing: '吸气4秒，呼气6秒',
            image: 'assets/exercises/exercise-core.png',
            targetMuscles: ['腹横肌', '膈肌'],
          ),
          Exercise(
            id: 'e5',
            name: '站立死虫',
            duration: 90,
            description: '核心稳定性训练',
            steps: [
              '靠墙站立，腰部贴墙',
              '抬起双手和对侧腿',
              '保持身体稳定',
              '左右交替进行',
            ],
            tips: '腰部始终贴紧墙面',
            breathing: '动作时呼气',
            image: 'assets/exercises/exercise-core.png',
            targetMuscles: ['腹直肌', '腹横肌'],
          ),
        ],
      ),
      WorkoutModule(
        id: 'm3',
        name: '下肢循环唤醒',
        duration: 5,
        exercises: [
          Exercise(
            id: 'e6',
            name: '椅子深蹲',
            duration: 90,
            description: '激活下肢肌群',
            steps: [
              '站在椅子前，双脚与肩同宽',
              '臀部向后坐，轻触椅面',
              '脚跟发力站起',
              '重复10-12次',
            ],
            tips: '膝盖不要内扣',
            breathing: '下蹲吸气，站起呼气',
            image: 'assets/exercises/exercise-leg.png',
            targetMuscles: ['股四头肌', '臀大肌'],
          ),
          Exercise(
            id: 'e7',
            name: '小腿拉伸',
            duration: 60,
            description: '缓解小腿紧张',
            steps: [
              '面向墙壁，双手扶墙',
              '一腿向后伸直，脚跟落地',
              '身体前倾感受拉伸',
              '左右各30秒',
            ],
            tips: '后腿膝盖保持伸直',
            breathing: '保持自然呼吸',
            image: 'assets/exercises/exercise-leg.png',
            targetMuscles: ['腓肠肌', '比目鱼肌'],
          ),
        ],
      ),
    ],
  );
}

/// 示例周数据
WeeklyStats getSampleWeeklyData() {
  return WeeklyStats(
    totalMinutes: 35,
    targetMinutes: 75,
    completedDays: 2,
    records: [
      DayRecord(
        date: '2024-01-22',
        dayOfWeek: 1,
        duration: 12,
        status: DayStatus.completed,
      ),
      DayRecord(
        date: '2024-01-23',
        dayOfWeek: 2,
        duration: 15,
        status: DayStatus.completed,
      ),
      DayRecord(
        date: '2024-01-24',
        dayOfWeek: 3,
        duration: 8,
        status: DayStatus.partial,
      ),
      DayRecord(
        date: '2024-01-25',
        dayOfWeek: 4,
        duration: 0,
        status: DayStatus.planned,
      ),
      DayRecord(
        date: '2024-01-26',
        dayOfWeek: 5,
        duration: 0,
        status: DayStatus.planned,
      ),
      DayRecord(
        date: '2024-01-27',
        dayOfWeek: 6,
        duration: 0,
        status: DayStatus.none,
      ),
      DayRecord(
        date: '2024-01-28',
        dayOfWeek: 0,
        duration: 0,
        status: DayStatus.none,
      ),
    ],
  );
}
