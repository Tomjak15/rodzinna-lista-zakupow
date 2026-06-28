import 'package:flutter/material.dart';

class ProductCategory {
  const ProductCategory({
    required this.name,
    required this.icon,
    required this.keywords,
    this.priority = 0,
  });

  final String name;
  final IconData icon;
  final List<String> keywords;
  final int priority;
}

const productCategories = <ProductCategory>[
  ProductCategory(
    name: 'Pieczywo',
    icon: Icons.bakery_dining,
    priority: 8,
    keywords: [
      'chleb',
      'chleb żytni',
      'chleb pszenny',
      'chleb tostowy',
      'chleb razowy',
      'chleb graham',
      'chleb kukurydziany',
      'bułka',
      'bułki',
      'kajzerka',
      'bagietka',
      'rogale',
      'croissant',
      'tost',
      'tortilla',
      'pita',
      'lawasz',
      'ciabatta',
      'drożdżówka',
      'pączek',
      'chałka',
    ],
  ),
  ProductCategory(
    name: 'Nabiał i jajka',
    icon: Icons.egg_alt,
    priority: 8,
    keywords: [
      'mleko',
      'mleko uht',
      'mleko bez laktozy',
      'masło',
      'margaryna',
      'śmietana',
      'śmietanka',
      'jogurt',
      'jogurt naturalny',
      'jogurt grecki',
      'kefir',
      'maślanka',
      'twaróg',
      'serek',
      'serek wiejski',
      'serek homogenizowany',
      'ser',
      'ser żółty',
      'ser biały',
      'ser pleśniowy',
      'mozzarella',
      'feta',
      'parmezan',
      'ricotta',
      'mascarpone',
      'skyr',
      'jajka',
      'jajko',
    ],
  ),
  ProductCategory(
    name: 'Mięso i wędliny',
    icon: Icons.set_meal,
    priority: 8,
    keywords: [
      'kurczak',
      'pierś z kurczaka',
      'udka',
      'skrzydełka',
      'indyk',
      'wołowina',
      'wieprzowina',
      'schab',
      'karkówka',
      'polędwica',
      'mięso',
      'mięso mielone',
      'mielone',
      'szynka',
      'kiełbasa',
      'parówki',
      'boczek',
      'salami',
      'pasztet',
      'żeberka',
      'wątróbka',
      'filet',
      'gyros',
      'mortadela',
      'baleron',
      'kabanosy',
    ],
  ),
  ProductCategory(
    name: 'Ryby',
    icon: Icons.phishing,
    priority: 8,
    keywords: [
      'ryba',
      'rybne',
      'łosoś',
      'dorsz',
      'tuńczyk',
      'makrela',
      'śledź',
      'śledzie',
      'pstrąg',
      'mintaj',
      'halibut',
      'krewetki',
      'paluszki rybne',
    ],
  ),
  ProductCategory(
    name: 'Sypkie i makarony',
    icon: Icons.grain,
    priority: 14,
    keywords: [
      'płatki kukurydziane',
      'płatki śniadaniowe',
      'płatki owsiane',
      'płatki jaglane',
      'płatki ryżowe',
      'corn flakes',
      'owsianka',
      'musli',
      'granola',
      'ryż',
      'ryż basmati',
      'ryż jaśminowy',
      'makaron',
      'spaghetti',
      'penne',
      'tagliatelle',
      'lasagne',
      'kasza',
      'kasza gryczana',
      'kasza jęczmienna',
      'kasza jaglana',
      'kasza kuskus',
      'kasza kukurydziana',
      'kuskus',
      'bulgur',
      'quinoa',
      'soczewica sucha',
      'fasola sucha',
      'ciecierzyca sucha',
      'mąka',
      'mąka pszenna',
      'mąka żytnia',
      'mąka ziemniaczana',
      'mąka kukurydziana',
      'skrobia',
      'cukier',
      'cukier puder',
      'sól',
      'bułka tarta',
      'drożdże',
      'proszek do pieczenia',
      'soda oczyszczona',
      'mak',
      'sezam',
      'słonecznik',
      'pestki dyni',
    ],
  ),
  ProductCategory(
    name: 'Warzywa',
    icon: Icons.eco,
    priority: 6,
    keywords: [
      'ziemniak',
      'marchew',
      'pietruszka korzeń',
      'seler',
      'por',
      'cebula',
      'czosnek',
      'pomidor',
      'pomidory',
      'ogórek',
      'ogórki',
      'papryka świeża',
      'sałata',
      'rukola',
      'roszponka',
      'szpinak',
      'kapusta',
      'brokuł',
      'kalafior',
      'cukinia',
      'bakłażan',
      'pieczarki',
      'grzyby',
      'fasolka',
      'groszek',
      'kukurydza',
      'kukurydza w puszce',
      'fasola',
      'fasola w puszce',
      'ciecierzyca',
      'soczewica',
      'burak',
      'rzodkiewka',
      'szczypiorek',
      'koperek',
      'natka pietruszki',
      'bazylia świeża',
      'mięta świeża',
      'jarmuż',
      'dynia',
      'batat',
      'imbir świeży',
      'chili świeże',
    ],
  ),
  ProductCategory(
    name: 'Owoce',
    icon: Icons.local_florist,
    priority: 6,
    keywords: [
      'jabłko',
      'jabłka',
      'banan',
      'pomarańcza',
      'mandarynka',
      'cytryna',
      'limonka',
      'gruszka',
      'winogrona',
      'truskawki',
      'maliny',
      'borówki',
      'jagody',
      'kiwi',
      'mango',
      'ananas',
      'arbuz',
      'melon',
      'awokado',
      'brzoskwinia',
      'nektarynka',
      'śliwka',
      'morela',
      'granat',
      'grejpfrut',
    ],
  ),
  ProductCategory(
    name: 'Przyprawy i sosy',
    icon: Icons.soup_kitchen,
    priority: 10,
    keywords: [
      'olej',
      'olej kukurydziany',
      'oliwa',
      'ocet',
      'majonez',
      'ketchup',
      'musztarda',
      'sos',
      'sos sojowy',
      'sos czosnkowy',
      'sos pomidorowy',
      'passata',
      'koncentrat',
      'koncentrat pomidorowy',
      'pesto',
      'chrzan',
      'przyprawa',
      'papryka słodka',
      'papryka ostra',
      'pieprz',
      'curry',
      'kurkuma',
      'oregano',
      'tymianek',
      'rozmaryn',
      'cynamon',
      'wanilia',
      'imbir mielony',
      'czosnek granulowany',
      'bulion',
      'kostka rosołowa',
      'liść laurowy',
      'ziele angielskie',
      'zioła prowansalskie',
    ],
  ),
  ProductCategory(
    name: 'Słodycze i przekąski',
    icon: Icons.cookie,
    priority: 12,
    keywords: [
      'chrupki kukurydziane',
      'paluszki kukurydziane',
      'nachosy',
      'popcorn',
      'czekolada',
      'baton',
      'batoniki',
      'ciastka',
      'ciasto',
      'herbatniki',
      'wafle',
      'wafelki',
      'chipsy',
      'paluszki',
      'krakersy',
      'precelki',
      'orzechy',
      'rodzynki',
      'żurawina',
      'migdały',
      'lody',
      'budyń',
      'kisiel',
      'galaretka',
      'dżem',
      'miód',
      'nutella',
      'masło orzechowe',
      'kakao',
      'cukierki',
      'żelki',
      'draże',
    ],
  ),
  ProductCategory(
    name: 'Napoje',
    icon: Icons.local_drink,
    priority: 8,
    keywords: [
      'woda',
      'woda gazowana',
      'woda niegazowana',
      'sok',
      'napój',
      'cola',
      'pepsi',
      'sprite',
      'lemoniada',
      'syrop',
      'kawa',
      'herbata',
      'kakao do picia',
      'ice tea',
      'energetyk',
      'oranżada',
    ],
  ),
  ProductCategory(
    name: 'Mrożonki',
    icon: Icons.ac_unit,
    priority: 9,
    keywords: [
      'mrożone',
      'mrożonka',
      'mrożony',
      'mrożona',
      'frytki',
      'pizza mrożona',
      'pierogi',
      'kopytka',
      'kluski śląskie',
      'warzywa mrożone',
      'mieszanka chińska',
      'szpinak mrożony',
      'owoce mrożone',
    ],
  ),
  ProductCategory(
    name: 'Chemia i dom',
    icon: Icons.cleaning_services,
    priority: 8,
    keywords: [
      'papier toaletowy',
      'ręcznik papierowy',
      'chusteczki',
      'mydło',
      'żel pod prysznic',
      'szampon',
      'odżywka',
      'pasta do zębów',
      'szczoteczka',
      'płyn do naczyń',
      'tabletki do zmywarki',
      'kapsułki do prania',
      'proszek do prania',
      'płyn do prania',
      'płyn do płukania',
      'worki na śmieci',
      'folia aluminiowa',
      'folia spożywcza',
      'papier do pieczenia',
      'gąbki',
      'ściereczki',
      'domestos',
      'ajax',
      'mleczko do czyszczenia',
      'odświeżacz',
    ],
  ),
  ProductCategory(
    name: 'Zwierzęta',
    icon: Icons.pets,
    priority: 8,
    keywords: [
      'karma dla psa',
      'karma dla kota',
      'karma',
      'żwirek',
      'smaczki',
      'saszetki',
    ],
  ),
];

String categoryForProduct(String productName) {
  final cleanName = _normalizeProductText(productName);
  if (cleanName.isEmpty) {
    return 'Inne';
  }

  ProductCategory? bestCategory;
  var bestScore = 0;
  for (final category in productCategories) {
    for (final keyword in category.keywords) {
      final cleanKeyword = _normalizeProductText(keyword);
      if (cleanKeyword.isEmpty ||
          !_containsProductKeyword(cleanName, cleanKeyword)) {
        continue;
      }
      final words = cleanKeyword
          .split(' ')
          .where((word) => word.isNotEmpty)
          .length;
      final score = cleanKeyword.length * 4 + words * 24 + category.priority;
      if (score > bestScore) {
        bestCategory = category;
        bestScore = score;
      }
    }
  }

  return bestCategory?.name ?? 'Inne';
}

IconData iconForCategory(String categoryName) {
  for (final category in productCategories) {
    if (category.name == categoryName) {
      return category.icon;
    }
  }
  return Icons.shopping_basket_outlined;
}

String productCategoryCacheKey(String productName) {
  return _normalizeProductText(productName);
}

bool _containsProductKeyword(String cleanName, String cleanKeyword) {
  if (cleanKeyword.contains(' ')) {
    return ' $cleanName '.contains(' $cleanKeyword ');
  }
  final tokens = cleanName.split(' ');
  if (cleanKeyword.length <= 3) {
    return tokens.contains(cleanKeyword);
  }
  return tokens.any(
    (token) => token == cleanKeyword || token.startsWith(cleanKeyword),
  );
}

String _normalizeProductText(String value) {
  return value
      .toLowerCase()
      .replaceAll('ą', 'a')
      .replaceAll('ć', 'c')
      .replaceAll('ę', 'e')
      .replaceAll('ł', 'l')
      .replaceAll('ń', 'n')
      .replaceAll('ó', 'o')
      .replaceAll('ś', 's')
      .replaceAll('ź', 'z')
      .replaceAll('ż', 'z')
      .replaceAll(RegExp(r'[^a-z0-9%]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
