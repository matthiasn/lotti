import 'package:flutter/material.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Icon glyph for every [CategoryIcon]. Exhaustiveness is enforced by
/// the all-values loop in `category_icon_test.dart`.
const Map<CategoryIcon, IconData> categoryIconData = {
  // Health & Wellness Icons
  CategoryIcon.fitness: LottiIcons.fitness,
  CategoryIcon.running: LottiIcons.running,
  CategoryIcon.swimming: LottiIcons.swimming,
  CategoryIcon.yoga: LucideIcons.accessibility,
  CategoryIcon.nutrition: LucideIcons.salad,
  CategoryIcon.water: LucideIcons.droplet,
  CategoryIcon.dining: LucideIcons.utensils,
  CategoryIcon.medical: LucideIcons.briefcaseMedical,
  CategoryIcon.medication: LucideIcons.pill,
  CategoryIcon.heartHealth: LucideIcons.heart,
  CategoryIcon.heartPulse: LottiIcons.heartRate,
  CategoryIcon.sleep: LucideIcons.bedDouble,
  CategoryIcon.bedtime: LottiIcons.night,
  CategoryIcon.mood: LucideIcons.smile,
  CategoryIcon.mindfulness: LucideIcons.sprout,
  CategoryIcon.mentalHealth: LucideIcons.brainCog,
  // Work & Productivity Icons
  CategoryIcon.checklist: LottiIcons.checkAll,
  CategoryIcon.assignment: LucideIcons.clipboardList,
  CategoryIcon.clipboard: LucideIcons.clipboardCheck,
  CategoryIcon.work: LottiIcons.work,
  CategoryIcon.meeting: LucideIcons.doorOpen,
  CategoryIcon.laptop: LottiIcons.laptop,
  CategoryIcon.home: LottiIcons.home,
  CategoryIcon.cleaning: LucideIcons.sprayCan,
  CategoryIcon.chores: LucideIcons.brush,
  CategoryIcon.shopping: LucideIcons.shoppingCart,
  CategoryIcon.groceries: LucideIcons.shoppingBasket,
  CategoryIcon.store: LucideIcons.store,
  CategoryIcon.commute: LucideIcons.trainFront,
  CategoryIcon.car: LucideIcons.car,
  CategoryIcon.transit: LucideIcons.tramFront,
  // Personal Development Icons
  CategoryIcon.reading: LucideIcons.bookOpen,
  CategoryIcon.writing: LucideIcons.penLine,
  CategoryIcon.journal: LottiIcons.book,
  CategoryIcon.school: LucideIcons.graduationCap,
  CategoryIcon.brain: LottiIcons.reasoning,
  CategoryIcon.learning: LucideIcons.lightbulb,
  CategoryIcon.people: LottiIcons.people,
  CategoryIcon.relationships: LucideIcons.heartHandshake,
  CategoryIcon.social: LucideIcons.usersRound,
  CategoryIcon.gaming: LucideIcons.gamepad2,
  CategoryIcon.music: LucideIcons.music,
  CategoryIcon.art: LottiIcons.palette,
  CategoryIcon.photography: LucideIcons.camera,
  CategoryIcon.baby: LucideIcons.baby,
  // Utility & Tracking Icons
  CategoryIcon.wallet: LucideIcons.wallet,
  CategoryIcon.money: LucideIcons.banknote,
  CategoryIcon.savings: LucideIcons.piggyBank,
  CategoryIcon.location: LottiIcons.location,
  CategoryIcon.travel: LucideIcons.globe,
  CategoryIcon.airplane: LucideIcons.plane,
  CategoryIcon.schedule: LottiIcons.schedule,
  CategoryIcon.calendar: LottiIcons.today,
  CategoryIcon.timer: LottiIcons.timer,
  CategoryIcon.phone: LottiIcons.phone,
  CategoryIcon.computer: LottiIcons.computer,
  CategoryIcon.connectivity: LucideIcons.wifi,
  // Nature & Outdoors Icons
  CategoryIcon.cycling: LottiIcons.cycling,
  CategoryIcon.hiking: LucideIcons.mountain,
  CategoryIcon.camping: LucideIcons.tent,
  CategoryIcon.pets: LucideIcons.pawPrint,
  CategoryIcon.garden: LucideIcons.flower,
  // Food & Drink Icons
  CategoryIcon.cooking: LucideIcons.chefHat,
  CategoryIcon.coffee: LucideIcons.coffee,
  // Communication Icons
  CategoryIcon.email: LucideIcons.mail,
  CategoryIcon.chat: LottiIcons.chat,
  CategoryIcon.videoCall: LottiIcons.video,
  // Entertainment Icons
  CategoryIcon.movie: LucideIcons.clapperboard,
  CategoryIcon.podcast: LucideIcons.podcast,
  CategoryIcon.theater: LucideIcons.drama,
  // Creative & Skills Icons
  CategoryIcon.coding: LottiIcons.code,
  CategoryIcon.crafts: LucideIcons.scissors,
  CategoryIcon.dance: LucideIcons.music4,
  // Household & Maintenance Icons
  CategoryIcon.laundry: LucideIcons.washingMachine,
  CategoryIcon.repair: LottiIcons.build,
  // Finance & Career Icons
  CategoryIcon.banking: LucideIcons.landmark,
  CategoryIcon.investment: LottiIcons.trendingUp,
  CategoryIcon.receipt: LucideIcons.receipt,
  // Events & Celebrations Icons
  CategoryIcon.celebration: LottiIcons.celebrate,
  CategoryIcon.gift: LucideIcons.gift,
  CategoryIcon.cake: LucideIcons.cake,
  // Education & Knowledge Icons
  CategoryIcon.language: LucideIcons.languages,
  CategoryIcon.science: LottiIcons.science,
  CategoryIcon.presentation: LucideIcons.presentation,
  // Spiritual & Well-being Icons
  CategoryIcon.prayer: LucideIcons.handHeart,
  CategoryIcon.gratitude: LucideIcons.sparkles,
  // Self-care & Wellness Icons
  CategoryIcon.spa: LucideIcons.flower2,
  CategoryIcon.stretching: LucideIcons.activity,
  // Weather & Nature Icons
  CategoryIcon.weather: LottiIcons.day,
  CategoryIcon.nature: LucideIcons.trees,
  // Volunteering Icons
  CategoryIcon.volunteer: LucideIcons.handHelping,
  CategoryIcon.recycling: LucideIcons.recycle,
};
