class BanksList {
  BanksList._();

  static const List<Map<String, String>> banks = [
    {'id': 'mellat', 'name': 'بانک ملت', 'code': '012'},
    {'id': 'melli', 'name': 'بانک ملی ایران', 'code': '017'},
    {'id': 'saderat', 'name': 'بانک صادرات ایران', 'code': '019'},
    {'id': 'tejarat', 'name': 'بانک تجارت', 'code': '018'},
    {'id': 'refah', 'name': 'بانک رفاه کارگران', 'code': '013'},
    {'id': 'keshavarzi', 'name': 'بانک کشاورزی', 'code': '016'},
    {'id': 'maskan', 'name': 'بانک مسکن', 'code': '014'},
    {'id': 'sepah', 'name': 'بانک سپه', 'code': '015'},
    {'id': 'sanaye', 'name': 'بانک صنعت و معدن', 'code': '011'},
    {'id': 'post', 'name': 'پست بانک ایران', 'code': '021'},
    {'id': 'tosee_saderat', 'name': 'بانک توسعه صادرات', 'code': '020'},
    {'id': 'eghtesad_novin', 'name': 'بانک اقتصاد نوین', 'code': '055'},
    {'id': 'parsian', 'name': 'بانک پارسیان', 'code': '054'},
    {'id': 'pasargad', 'name': 'بانک پاسارگاد', 'code': '057'},
    {'id': 'karafarin', 'name': 'بانک کارآفرین', 'code': '053'},
    {'id': 'saman', 'name': 'بانک سامان', 'code': '056'},
    {'id': 'sina', 'name': 'بانک سینا', 'code': '059'},
    {'id': 'shahr', 'name': 'بانک شهر', 'code': '061'},
    {'id': 'ayandeh', 'name': 'بانک آینده', 'code': '062'},
    {'id': 'ansar', 'name': 'بانک انصار', 'code': '063'},
    {'id': 'gardeshgari', 'name': 'بانک گردشگری', 'code': '064'},
    {'id': 'hekmat_iranian', 'name': 'بانک حکمت ایرانیان', 'code': '065'},
    {'id': 'dey', 'name': 'بانک دی', 'code': '066'},
    {'id': 'iran_zamin', 'name': 'بانک ایران زمین', 'code': '069'},
    {'id': 'mehr_iran', 'name': 'بانک مهر ایران', 'code': '060'},
    {'id': 'resalat', 'name': 'بانک قرض‌الحسنه رسالت', 'code': '070'},
    {'id': 'mehre_eghtesad', 'name': 'بانک قرض‌الحسنه مهر ایران', 'code': '060'},
    {'id': 'middle_east', 'name': 'بانک خاورمیانه', 'code': '079'},
    {'id': 'nour', 'name': 'بانک نور', 'code': '080'},
  ];

  static String? getNameById(String id) {
    final bank = banks.firstWhere(
      (b) => b['id'] == id,
      orElse: () => {},
    );
    return bank['name'];
  }

  static List<Map<String, String>> search(String query) {
    if (query.isEmpty) return banks;
    final q = query.trim().toLowerCase();
    return banks.where((b) {
      final name = b['name']!.toLowerCase();
      return name.contains(q);
    }).toList();
  }
}
