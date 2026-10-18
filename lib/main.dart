import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CafeDb.instance.init();
  runApp(const LindaCafeApp());
}

String money(num n) => NumberFormat('#,##0', 'en_US').format(n);

class CafeDb {
  CafeDb._();
  static final instance = CafeDb._();
  late Database db;
  Future<void> init() async {
    final path = p.join(await getDatabasesPath(), 'linda_cafe.db');
    db = await openDatabase(path, version: 1, onCreate: (d, v) async {
      await d.execute('CREATE TABLE products(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, category TEXT, price INTEGER NOT NULL, cost INTEGER NOT NULL DEFAULT 0, stock REAL NOT NULL DEFAULT 0, low_stock REAL NOT NULL DEFAULT 3)');
      await d.execute('CREATE TABLE sales(id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER, product_name TEXT, qty REAL, unit_price INTEGER, total INTEGER, created_at TEXT)');
      await d.execute('CREATE TABLE entries(id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT, title TEXT, amount INTEGER, note TEXT, created_at TEXT)');
      await d.execute('CREATE TABLE debts(id INTEGER PRIMARY KEY AUTOINCREMENT, person TEXT, kind TEXT, amount INTEGER, paid INTEGER DEFAULT 0, note TEXT, created_at TEXT)');
      await d.execute('CREATE TABLE staff(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, role TEXT, salary INTEGER, phone TEXT)');
      await d.execute('CREATE TABLE purchases(id INTEGER PRIMARY KEY AUTOINCREMENT, supplier TEXT, product_id INTEGER, product_name TEXT, qty REAL, amount INTEGER, created_at TEXT)');
    });
  }
  Future<List<Map<String,Object?>>> rows(String table, {String? orderBy}) => db.query(table, orderBy: orderBy ?? 'id DESC');
  Future<int> add(String table, Map<String,Object?> values) => db.insert(table, values);
  Future<int> remove(String table, int id) => db.delete(table, where: 'id=?', whereArgs: [id]);
  Future<void> sell(Map<String,Object?> product, double qty) async {
    final id = product['id'] as int;
    final price = product['price'] as int;
    final total = (price * qty).round();
    await db.transaction((txn) async {
      await txn.insert('sales', {'product_id': id, 'product_name': product['name'], 'qty': qty, 'unit_price': price, 'total': total, 'created_at': DateTime.now().toIso8601String()});
      await txn.update('products', {'stock': (product['stock'] as num).toDouble() - qty}, where: 'id=?', whereArgs: [id]);
    });
  }
}

class LindaCafeApp extends StatelessWidget {
  const LindaCafeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'مدیریت کافه لیندا', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff59665d), brightness: Brightness.light), useMaterial3: true, scaffoldBackgroundColor: const Color(0xfff7f7f3), appBarTheme: const AppBarTheme(backgroundColor: Color(0xfff7f7f3), centerTitle: false)),
    builder: (context, child) => Directionality(textDirection: TextDirection.rtl,child: child!,
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState() => _HomePageState(); }
class _HomePageState extends State<HomePage> {
  int tab = 0;
  final titles = const ['داشبورد', 'فروش و سفارش', 'انبار و منو', 'هزینه‌ها', 'حساب‌ها', 'پرسنل', 'گزارش‌ها'];
  Future<void> refresh() async { if (mounted) setState(() {}); }
  @override Widget build(BuildContext context) {
    final pages = [DashboardPage(onChanged: refresh), SalesPage(onChanged: refresh), ProductsPage(onChanged: refresh), EntriesPage(onChanged: refresh), DebtsPage(onChanged: refresh), StaffPage(onChanged: refresh), ReportsPage()];
    return Scaffold(
      appBar: AppBar(title: Row(children: [const Icon(Icons.coffee, size: 27), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('کافه لیندا', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), Text(titles[tab], style: Theme.of(context).textTheme.bodySmall)])]), actions: [IconButton(tooltip: 'به‌روزرسانی', onPressed: refresh, icon: const Icon(Icons.refresh))]),
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'خانه'), NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'فروش'), NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'انبار'), NavigationDestination(icon: Icon(Icons.receipt_long), label: 'هزینه'), NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'حساب'), NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'پرسنل'), NavigationDestination(icon: Icon(Icons.bar_chart), label: 'گزارش')]),
    );
  }
}

Widget pagePad(Widget child) => Padding(padding: const EdgeInsets.all(16), child: child);
Widget sectionTitle(String text, {Widget? trailing}) => Padding(padding: const EdgeInsets.only(bottom: 12, top: 4), child: Row(children: [Expanded(child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))), if (trailing != null) trailing]));
Widget emptyState(String text) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.inbox_outlined, size: 42, color: Colors.grey), const SizedBox(height: 8), Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey))])));
Widget statCard(String title, String value, IconData icon, {Color? color}) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [CircleAvatar(backgroundColor: (color ?? const Color(0xff59665d)).withOpacity(.12), child: Icon(icon, color: color ?? const Color(0xff59665d))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12)), const SizedBox(height: 4), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))]))])));

class DashboardPage extends StatelessWidget {
  final VoidCallback onChanged; const DashboardPage({super.key, required this.onChanged});
  Future<Map<String, num>> summary() async {
    final db = CafeDb.instance.db;
    final today = DateTime.now(); final start = DateTime(today.year,today.month,today.day).toIso8601String();
    final s = await db.rawQuery('SELECT COALESCE(SUM(total),0) v FROM sales WHERE created_at >= ?', [start]);
    final e = await db.rawQuery("SELECT COALESCE(SUM(amount),0) v FROM entries WHERE type='expense' AND created_at >= ?", [start]);
    final all = await db.rawQuery('SELECT COUNT(*) c FROM products');
    final low = await db.rawQuery('SELECT COUNT(*) c FROM products WHERE stock <= low_stock');
    final due = await db.rawQuery('SELECT COALESCE(SUM(amount-paid),0) v FROM debts');
    return {'sales': (s.first['v'] as num), 'expenses': e.first['v'] as num, 'products': all.first['c'] as num, 'low': low.first['c'] as num, 'debts': due.first['v'] as num};
  }
  @override Widget build(BuildContext context) => FutureBuilder<Map<String,num>>(future: summary(), builder: (c,s) { if (!s.hasData) return const Center(child: CircularProgressIndicator()); final d=s.data!; return RefreshIndicator(onRefresh: () async { onChanged(); }, child: ListView(padding: const EdgeInsets.all(16), children: [Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xff59665d), borderRadius: BorderRadius.circular(20)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('خوش آمدید 👋', style: TextStyle(color: Colors.white70)), SizedBox(height: 6), Text('مدیریت کافه لیندا', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold)), SizedBox(height: 5), Text('فروش، موجودی و دخل‌وخرج کافه در یک‌جا', style: TextStyle(color: Colors.white70))]),), const SizedBox(height: 18), sectionTitle('وضعیت امروز'), GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 1.65, crossAxisSpacing: 8, mainAxisSpacing: 8, children: [statCard('فروش امروز', '${money(d['sales']!)} تومان', Icons.trending_up, color: Colors.green), statCard('هزینه امروز', '${money(d['expenses']!)} تومان', Icons.payments_outlined, color: Colors.orange), statCard('تعداد کالاها', '${money(d['products']!)} قلم', Icons.inventory_2_outlined), statCard('موجودی کم', '${money(d['low']!)} قلم', Icons.warning_amber, color: Colors.red), statCard('مانده حساب‌ها', '${money(d['debts']!)} تومان', Icons.account_balance_wallet)]), const SizedBox(height: 18), const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('راهنما: ابتدا کالاها و قیمت فروش را در بخش «انبار» ثبت کنید. سپس از بخش «فروش» سفارش بزنید تا موجودی انبار به‌صورت خودکار کم شود.', style: TextStyle(height: 1.7))))])); });
}

class ProductsPage extends StatefulWidget { final VoidCallback onChanged; const ProductsPage({super.key, required this.onChanged}); @override State<ProductsPage> createState()=>_ProductsPageState(); }
class _ProductsPageState extends State<ProductsPage> {
 Future<void> addProduct() async { final name=TextEditingController(), cat=TextEditingController(text:'نوشیدنی'), price=TextEditingController(), cost=TextEditingController(), stock=TextEditingController(text:'0'), low=TextEditingController(text:'3'); final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('افزودن کالا به منو'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[field(name,'نام محصول'),field(cat,'دسته‌بندی'),field(price,'قیمت فروش (تومان)',num:true),field(cost,'بهای تمام‌شده (تومان)',num:true),field(stock,'موجودی فعلی',num:true),field(low,'هشدار موجودی در حد',num:true)])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ذخیره'))])); if(ok==true && name.text.trim().isNotEmpty && int.tryParse(price.text)!=null){await CafeDb.instance.add('products',{'name':name.text.trim(),'category':cat.text.trim(),'price':int.parse(price.text),'cost':int.tryParse(cost.text)??0,'stock':double.tryParse(stock.text)??0,'low_stock':double.tryParse(low.text)??3}); widget.onChanged(); setState((){});} }
 @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,Object?>>>(future:CafeDb.instance.rows('products'),builder:(c,s){final rows=s.data??[]; return pagePad(Column(children:[sectionTitle('منو و موجودی انبار',trailing:FilledButton.icon(onPressed:addProduct,icon:const Icon(Icons.add),label:const Text('افزودن'))),Expanded(child:rows.isEmpty?emptyState('هنوز محصولی ثبت نشده است. از دکمه افزودن شروع کنید.'):ListView.builder(itemCount:rows.length,itemBuilder:(c,i){final r=rows[i];final low=(r['stock'] as num)<=(r['low_stock'] as num);return Card(child:ListTile(leading:CircleAvatar(child:Icon(low?Icons.warning_amber:Icons.local_cafe,color:low?Colors.red:null)),title:Text('${r['name']}'),subtitle:Text('${r['category']??''} • موجودی: ${r['stock']} ${low?'• موجودی کم':''}'),trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[Text('${money(r['price'] as num)} تومان',style:const TextStyle(fontWeight:FontWeight.bold)),IconButton(onPressed:()async{await CafeDb.instance.remove('products',r['id'] as int);widget.onChanged();setState((){});},icon:const Icon(Icons.delete_outline,size:20))])));})),const SizedBox(height:4)]));});
}

class SalesPage extends StatefulWidget {final VoidCallback onChanged;const SalesPage({super.key,required this.onChanged});@override State<SalesPage> createState()=>_SalesPageState();}
class _SalesPageState extends State<SalesPage>{
 Future<void> sell(Map<String,Object?> product) async {final q=TextEditingController(text:'1'); final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text('ثبت فروش: ${product['name']}'),content:Column(mainAxisSize:MainAxisSize.min,children:[Text('قیمت واحد: ${money(product['price'] as num)} تومان'),const SizedBox(height:12),field(q,'تعداد',num:true)]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت فروش'))]));if(ok==true){final qty=double.tryParse(q.text)??0;if(qty<=0){return;} if(qty>(product['stock'] as num)){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('موجودی کافی نیست')));return;} await CafeDb.instance.sell(product,qty);widget.onChanged();setState((){});}}
 @override
 Widget build(BuildContext context) => FutureBuilder<List<Map<String, Object?>>>(
   future: CafeDb.instance.rows('products'),
   builder: (context, snapshot) {
     final rows = snapshot.data ?? <Map<String, Object?>>[];
     return pagePad(Column(children: [
       sectionTitle('ثبت سفارش و فروش'),
       const Align(
         alignment: Alignment.centerRight,
         child: Text('برای ثبت فروش، روی محصول بزنید. موجودی خودکار کسر می‌شود.', style: TextStyle(color: Colors.black54)),
       ),
       const SizedBox(height: 12),
       Expanded(
         child: rows.isEmpty
           ? emptyState('برای شروع فروش، ابتدا از بخش انبار محصول ثبت کنید.')
           : ListView(children: rows.map<Widget>((r) => Card(
               child: ListTile(
                 leading: const CircleAvatar(child: Icon(Icons.coffee)),
                 title: Text('${r['name']}'),
                 subtitle: Text('موجودی: ${r['stock']}'),
                 trailing: FilledButton(
                   onPressed: (r['stock'] as num) > 0 ? () => sell(r) : null,
                   child: Text('${money(r['price'] as num)} تومان'),
                 ),
               ),
             )).toList()),
       ),
     ]));
   },
 );
}

class EntriesPage extends StatefulWidget{final VoidCallback onChanged;const EntriesPage({super.key,required this.onChanged});@override State<EntriesPage> createState()=>_EntriesPageState();}
class _EntriesPageState extends State<EntriesPage>{
 Future<void> addEntry()async{String type='expense';final title=TextEditingController(),amount=TextEditingController(),note=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,ss)=>AlertDialog(title:const Text('ثبت دخل‌وخرج'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(value:type,decoration:const InputDecoration(labelText:'نوع تراکنش'),items:const [DropdownMenuItem(value:'expense',child:Text('هزینه')),DropdownMenuItem(value:'income',child:Text('درآمد متفرقه'))],onChanged:(v)=>ss(()=>type=v??'expense')),field(title,'عنوان'),field(amount,'مبلغ (تومان)',num:true),field(note,'توضیحات (اختیاری)')])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت'))])));if(ok==true&&title.text.trim().isNotEmpty&&int.tryParse(amount.text)!=null){await CafeDb.instance.add('entries',{'type':type,'title':title.text.trim(),'amount':int.parse(amount.text),'note':note.text.trim(),'created_at':DateTime.now().toIso8601String()});widget.onChanged();setState((){});}}
 @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,Object?>>>(future:CafeDb.instance.rows('entries'),builder:(c,s){final rows=s.data??[];return pagePad(Column(children:[sectionTitle('هزینه‌ها و درآمدهای متفرقه',trailing:FilledButton.icon(onPressed:addEntry,icon:const Icon(Icons.add),label:const Text('ثبت'))),Expanded(child:rows.isEmpty?emptyState('هزینه‌هایی مانند اجاره، حقوق، قبض و خریدهای متفرقه را اینجا ثبت کنید.'):ListView.builder(itemCount:rows.length,itemBuilder:(c,i){final r=rows[i];final income=r['type']=='income';return Card(child:ListTile(leading:CircleAvatar(child:Icon(income?Icons.south_west:Icons.north_east,color:income?Colors.green:Colors.orange)),title:Text('${r['title']}'),subtitle:Text('${r['note']??''} • ${(r['created_at'] as String).substring(0,10)}'),trailing:Text('${income?'+':'−'} ${money(r['amount'] as num)} تومان',style:TextStyle(fontWeight:FontWeight.bold,color:income?Colors.green:Colors.orange))));}))]));});
}

class DebtsPage extends StatefulWidget{final VoidCallback onChanged;const DebtsPage({super.key,required this.onChanged});@override State<DebtsPage> createState()=>_DebtsPageState();}
class _DebtsPageState extends State<DebtsPage>{Future<void> addDebt()async{final person=TextEditingController(),amount=TextEditingController(),note=TextEditingController();String kind='payable';final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,ss)=>AlertDialog(title:const Text('ثبت حساب شخص/شرکت'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(value:kind,decoration:const InputDecoration(labelText:'نوع حساب'),items:const [DropdownMenuItem(value:'payable',child:Text('بدهی ما به دیگران')),DropdownMenuItem(value:'receivable',child:Text('طلب ما از دیگران'))],onChanged:(v)=>ss(()=>kind=v??'payable')),field(person,'نام شخص یا تأمین‌کننده'),field(amount,'مبلغ کل (تومان)',num:true),field(note,'توضیحات')])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ذخیره'))])));if(ok==true&&person.text.trim().isNotEmpty&&int.tryParse(amount.text)!=null){await CafeDb.instance.add('debts',{'person':person.text.trim(),'kind':kind,'amount':int.parse(amount.text),'paid':0,'note':note.text.trim(),'created_at':DateTime.now().toIso8601String()});widget.onChanged();setState((){});}}
 Future<void> pay(Map<String,Object?> r)async{final value=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('ثبت پرداخت / دریافت'),content:field(value,'مبلغ این مرحله (تومان)',num:true),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت'))]));if(ok==true){final n=int.tryParse(value.text)??0;final remain=(r['amount'] as int)-(r['paid'] as int);if(n>0){await CafeDb.instance.db.update('debts',{'paid':(r['paid'] as int)+(n>remain?remain:n)},where:'id=?',whereArgs:[r['id']]);setState((){});widget.onChanged();}}}
 @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,Object?>>>(future:CafeDb.instance.rows('debts'),builder:(c,s){final rows=s.data??[];return pagePad(Column(children:[sectionTitle('بدهی‌ها و طلب‌ها',trailing:FilledButton.icon(onPressed:addDebt,icon:const Icon(Icons.add),label:const Text('افزودن'))),Expanded(child:rows.isEmpty?emptyState('بدهی به تأمین‌کننده یا طلب از مشتری را اینجا مدیریت کنید.'):ListView.builder(itemCount:rows.length,itemBuilder:(c,i){final r=rows[i];final remain=(r['amount'] as int)-(r['paid'] as int);return Card(child:ListTile(title:Text('${r['person']}'),subtitle:Text('${r['kind']=='payable'?'بدهی ما':'طلب ما'} • مانده: ${money(remain)} تومان'),trailing:remain>0?IconButton(onPressed:()=>pay(r),icon:const Icon(Icons.payments_outlined)):const Icon(Icons.check_circle,color:Colors.green)));}))]));});}

class StaffPage extends StatefulWidget{final VoidCallback onChanged;const StaffPage({super.key,required this.onChanged});@override State<StaffPage> createState()=>_StaffPageState();}
class _StaffPageState extends State<StaffPage>{Future<void> addStaff()async{final name=TextEditingController(),role=TextEditingController(),salary=TextEditingController(),phone=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('افزودن پرسنل'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[field(name,'نام و نام خانوادگی'),field(role,'سمت'),field(salary,'حقوق ماهانه (تومان)',num:true),field(phone,'شماره تماس (اختیاری)')])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ذخیره'))]));if(ok==true&&name.text.trim().isNotEmpty){await CafeDb.instance.add('staff',{'name':name.text.trim(),'role':role.text.trim(),'salary':int.tryParse(salary.text)??0,'phone':phone.text.trim()});setState((){});widget.onChanged();}}
 @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,Object?>>>(future:CafeDb.instance.rows('staff'),builder:(c,s){final rows=s.data??[];return pagePad(Column(children:[sectionTitle('مدیریت پرسنل و حقوق',trailing:FilledButton.icon(onPressed:addStaff,icon:const Icon(Icons.person_add_alt),label:const Text('افزودن'))),Expanded(child:rows.isEmpty?emptyState('اطلاعات کارکنان و حقوق ماهانه را ثبت کنید.'):ListView.builder(itemCount:rows.length,itemBuilder:(c,i){final r=rows[i];return Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text('${r['name']}'),subtitle:Text('${r['role']} • ${r['phone']}'),trailing:Text('${money(r['salary'] as num)} تومان')));}))]));});}

class ReportsPage extends StatelessWidget{const ReportsPage({super.key});Future<Map<String,int>> data()async{final db=CafeDb.instance.db;final sales=await db.rawQuery('SELECT COALESCE(SUM(total),0) v FROM sales');final cost=await db.rawQuery('SELECT COALESCE(SUM(amount),0) v FROM entries WHERE type="expense"');final income=await db.rawQuery('SELECT COALESCE(SUM(amount),0) v FROM entries WHERE type="income"');final sold=await db.rawQuery('SELECT COUNT(*) c FROM sales');return {'sales':(sales.first['v'] as num).toInt(),'expenses':(cost.first['v'] as num).toInt(),'income':(income.first['v'] as num).toInt(),'orders':(sold.first['c'] as num).toInt()};}
 @override Widget build(BuildContext context)=>FutureBuilder<Map<String,int>>(future:data(),builder:(c,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());final d=s.data!;final net=d['sales']!+d['income']!-d['expenses']!;return pagePad(ListView(children:[sectionTitle('گزارش کلی از زمان نصب'),statCard('مجموع فروش ثبت‌شده','${money(d['sales']!)} تومان',Icons.point_of_sale),statCard('درآمدهای متفرقه','${money(d['income']!)} تومان',Icons.south_west,color:Colors.green),statCard('هزینه‌های ثبت‌شده','${money(d['expenses']!)} تومان',Icons.payments,color:Colors.orange),statCard('تعداد سفارش‌ها','${money(d['orders']!)} سفارش',Icons.receipt_long),const SizedBox(height:8),Card(child:ListTile(leading:Icon(net>=0?Icons.trending_up:Icons.trending_down,color:net>=0?Colors.green:Colors.red),title:const Text('مانده ساده درآمد و هزینه'),subtitle:const Text('فروش + درآمد متفرقه − هزینه‌ها (بدون محاسبه بهای تمام‌شده کالا و حقوق ثبت‌نشده)'),trailing:Text('${money(net)} تومان',style:const TextStyle(fontWeight:FontWeight.bold))))]));});}

Widget field(TextEditingController c,String label,{bool num=false})=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:TextField(controller:c,keyboardType:num?const TextInputType.numberWithOptions(decimal:true):TextInputType.text,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder(),isDense:true)));
