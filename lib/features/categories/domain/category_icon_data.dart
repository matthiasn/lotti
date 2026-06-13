import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';

/// Icon glyph for every [CategoryIcon]. Exhaustiveness is enforced by
/// the all-values loop in `category_icon_test.dart`.
const Map<CategoryIcon, IconData> categoryIconData = {
  // Health & Wellness Icons
  CategoryIcon.fitness: Icons.fitness_center,
  CategoryIcon.running: Icons.directions_run,
  CategoryIcon.swimming: Icons.pool,
  CategoryIcon.yoga: MdiIcons.yoga,
  CategoryIcon.nutrition: Icons.restaurant,
  CategoryIcon.water: Icons.water_drop,
  CategoryIcon.dining: Icons.local_dining,
  CategoryIcon.medical: Icons.medical_services,
  CategoryIcon.medication: Icons.medication,
  CategoryIcon.heartHealth: Icons.favorite,
  CategoryIcon.heartPulse: MdiIcons.heartPulse,
  CategoryIcon.sleep: MdiIcons.sleep,
  CategoryIcon.bedtime: Icons.bedtime,
  CategoryIcon.mood: Icons.mood,
  CategoryIcon.mindfulness: Icons.self_improvement,
  CategoryIcon.mentalHealth: MdiIcons.headHeart,
  // Work & Productivity Icons
  CategoryIcon.checklist: Icons.checklist,
  CategoryIcon.assignment: Icons.assignment,
  CategoryIcon.clipboard: MdiIcons.clipboardCheck,
  CategoryIcon.work: Icons.work,
  CategoryIcon.meeting: Icons.meeting_room,
  CategoryIcon.laptop: Icons.laptop_mac,
  CategoryIcon.home: Icons.home,
  CategoryIcon.cleaning: Icons.cleaning_services,
  CategoryIcon.chores: MdiIcons.broom,
  CategoryIcon.shopping: Icons.shopping_cart,
  CategoryIcon.groceries: Icons.local_grocery_store,
  CategoryIcon.store: Icons.store,
  CategoryIcon.commute: Icons.commute,
  CategoryIcon.car: Icons.directions_car,
  CategoryIcon.transit: Icons.directions_transit,
  // Personal Development Icons
  CategoryIcon.reading: Icons.menu_book,
  CategoryIcon.writing: Icons.create,
  CategoryIcon.journal: Icons.book,
  CategoryIcon.school: Icons.school,
  CategoryIcon.brain: Icons.psychology,
  CategoryIcon.learning: MdiIcons.lightbulbOn,
  CategoryIcon.people: Icons.people,
  CategoryIcon.relationships: Icons.favorite,
  CategoryIcon.social: MdiIcons.accountGroup,
  CategoryIcon.gaming: Icons.games,
  CategoryIcon.music: Icons.music_note,
  CategoryIcon.art: Icons.palette,
  CategoryIcon.photography: MdiIcons.cameraOutline,
  CategoryIcon.baby: Icons.baby_changing_station,
  // Utility & Tracking Icons
  CategoryIcon.wallet: Icons.account_balance_wallet,
  CategoryIcon.money: Icons.attach_money,
  CategoryIcon.savings: MdiIcons.piggyBank,
  CategoryIcon.location: Icons.location_on,
  CategoryIcon.travel: Icons.travel_explore,
  CategoryIcon.airplane: MdiIcons.airplane,
  CategoryIcon.schedule: Icons.schedule,
  CategoryIcon.calendar: Icons.calendar_today,
  CategoryIcon.timer: Icons.timer,
  CategoryIcon.phone: Icons.smartphone,
  CategoryIcon.computer: Icons.computer,
  CategoryIcon.connectivity: MdiIcons.wifi,
  // Nature & Outdoors Icons
  CategoryIcon.cycling: Icons.directions_bike,
  CategoryIcon.hiking: Icons.hiking,
  CategoryIcon.camping: MdiIcons.tent,
  CategoryIcon.pets: Icons.pets,
  CategoryIcon.garden: MdiIcons.flower,
  // Food & Drink Icons
  CategoryIcon.cooking: MdiIcons.chefHat,
  CategoryIcon.coffee: Icons.coffee,
  // Communication Icons
  CategoryIcon.email: Icons.email,
  CategoryIcon.chat: Icons.chat,
  CategoryIcon.videoCall: Icons.videocam,
  // Entertainment Icons
  CategoryIcon.movie: Icons.movie,
  CategoryIcon.podcast: Icons.podcasts,
  CategoryIcon.theater: Icons.theater_comedy,
  // Creative & Skills Icons
  CategoryIcon.coding: Icons.code,
  CategoryIcon.crafts: Icons.handyman,
  CategoryIcon.dance: MdiIcons.danceBallroom,
  // Household & Maintenance Icons
  CategoryIcon.laundry: MdiIcons.washingMachine,
  CategoryIcon.repair: Icons.build,
  // Finance & Career Icons
  CategoryIcon.banking: Icons.account_balance,
  CategoryIcon.investment: Icons.trending_up,
  CategoryIcon.receipt: Icons.receipt_long,
  // Events & Celebrations Icons
  CategoryIcon.celebration: Icons.celebration,
  CategoryIcon.gift: Icons.card_giftcard,
  CategoryIcon.cake: Icons.cake,
  // Education & Knowledge Icons
  CategoryIcon.language: Icons.translate,
  CategoryIcon.science: Icons.science,
  CategoryIcon.presentation: MdiIcons.presentationPlay,
  // Spiritual & Well-being Icons
  CategoryIcon.prayer: MdiIcons.handsPray,
  CategoryIcon.gratitude: MdiIcons.handHeart,
  // Self-care & Wellness Icons
  CategoryIcon.spa: Icons.spa,
  CategoryIcon.stretching: MdiIcons.humanHandsup,
  // Weather & Nature Icons
  CategoryIcon.weather: Icons.wb_sunny,
  CategoryIcon.nature: Icons.park,
  // Volunteering Icons
  CategoryIcon.volunteer: Icons.volunteer_activism,
  CategoryIcon.recycling: Icons.recycling,
};
