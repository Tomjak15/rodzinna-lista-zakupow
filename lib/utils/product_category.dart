import 'package:flutter/material.dart';

class ProductCategory {
  const ProductCategory({
    required this.name,
    required this.icon,
    required this.keywords,
  });

  final String name;
  final IconData icon;
  final List<String> keywords;
}

const productCategories = <ProductCategory>[
  ProductCategory(
    name: 'Pieczywo',
    icon: Icons.bakery_dining,
    keywords: ['chleb', 'buł', 'bagiet', 'kajzer', 'rog', 'tost', 'ciabatt'],
  ),
  ProductCategory(
    name: 'Nabiał i jajka',
    icon: Icons.egg_alt,
    keywords: [
      'mleko',
      'masło',
      'śmietan',
      'jogurt',
      'kefir',
      'maślank',
      'twaróg',
      'serek',
      'ser ',
      'mozzarella',
      'feta',
      'parmezan',
      'jaj',
    ],
  ),
  ProductCategory(
    name: 'Mięso i wędliny',
    icon: Icons.set_meal,
    keywords: [
      'kurczak',
      'indyk',
      'wołow',
      'wieprz',
      'schab',
      'karków',
      'mięso',
      'mielone',
      'szynk',
      'kiełbas',
      'parów',
      'boczek',
      'salami',
      'pasztet',
      'żeber',
      'wątrób',
    ],
  ),
  ProductCategory(
    name: 'Ryby',
    icon: Icons.phishing,
    keywords: ['ryb', 'łosoś', 'dorsz', 'tuńczyk', 'makrel', 'śled', 'krewet'],
  ),
  ProductCategory(
    name: 'Warzywa',
    icon: Icons.eco,
    keywords: [
      'ziemni',
      'marchew',
      'pietrusz',
      'seler',
      'por',
      'cebula',
      'czosnek',
      'pomidor',
      'ogór',
      'papryk',
      'sałat',
      'rukol',
      'szpinak',
      'kapust',
      'brokuł',
      'kalafior',
      'cukini',
      'bakłaż',
      'pieczar',
      'grzyb',
      'fasolk',
      'groszek',
      'kukurydz',
      'fasola',
      'ciecier',
      'soczew',
      'burak',
      'rzodkiew',
      'szczypior',
      'koperek',
      'natka',
      'bazylia',
      'mięta',
    ],
  ),
  ProductCategory(
    name: 'Owoce',
    icon: Icons.local_florist,
    keywords: [
      'jabł',
      'banan',
      'pomarań',
      'mandaryn',
      'cytryn',
      'limonk',
      'grusz',
      'winogron',
      'truskaw',
      'malin',
      'borów',
      'jagod',
      'kiwi',
      'mango',
      'ananas',
      'arbuz',
      'melon',
      'awokado',
    ],
  ),
  ProductCategory(
    name: 'Sypkie i makarony',
    icon: Icons.grain,
    keywords: [
      'ryż',
      'makaron',
      'kasz',
      'kuskus',
      'płatki',
      'musli',
      'granola',
      'mąka',
      'cukier',
      'sól',
      'bułka tarta',
      'drożdż',
    ],
  ),
  ProductCategory(
    name: 'Przyprawy i sosy',
    icon: Icons.soup_kitchen,
    keywords: [
      'olej',
      'oliwa',
      'ocet',
      'majonez',
      'ketchup',
      'musztard',
      'sos',
      'passata',
      'koncentrat',
      'pesto',
      'chrzan',
      'papryka słodka',
      'pieprz',
      'curry',
      'kurkuma',
      'oregano',
      'tymianek',
      'rozmaryn',
      'cynamon',
      'wanilia',
      'imbir',
      'bulion',
    ],
  ),
  ProductCategory(
    name: 'Słodycze i przekąski',
    icon: Icons.cookie,
    keywords: [
      'czekolad',
      'baton',
      'ciast',
      'herbatnik',
      'chips',
      'palusz',
      'krakers',
      'orzech',
      'rodzyn',
      'żurawin',
      'migdał',
      'lody',
      'budyń',
      'kisiel',
      'galaret',
    ],
  ),
  ProductCategory(
    name: 'Napoje',
    icon: Icons.local_drink,
    keywords: [
      'woda',
      'sok',
      'napój',
      'cola',
      'lemoniad',
      'syrop',
      'kawa',
      'herbata',
    ],
  ),
  ProductCategory(
    name: 'Mrożonki',
    icon: Icons.ac_unit,
    keywords: ['mroż', 'frytki', 'pierogi', 'kopytka', 'kluski'],
  ),
  ProductCategory(
    name: 'Chemia i dom',
    icon: Icons.cleaning_services,
    keywords: [
      'papier',
      'ręcznik',
      'chustecz',
      'mydło',
      'żel',
      'szampon',
      'pasta',
      'szczotecz',
      'płyn',
      'tabletki',
      'proszek',
      'worki',
      'folia',
      'gąbki',
      'ścierecz',
    ],
  ),
  ProductCategory(
    name: 'Zwierzęta',
    icon: Icons.pets,
    keywords: ['karma', 'żwirek'],
  ),
];

String categoryForProduct(String productName) {
  final cleanName = productName.toLowerCase();
  for (final category in productCategories) {
    if (category.keywords.any((keyword) => cleanName.contains(keyword))) {
      return category.name;
    }
  }
  return 'Inne';
}

IconData iconForCategory(String categoryName) {
  for (final category in productCategories) {
    if (category.name == categoryName) {
      return category.icon;
    }
  }
  return Icons.shopping_basket_outlined;
}
