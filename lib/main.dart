import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutterfire_ui/auth.dart';
import 'package:flutterfire_ui/firestore.dart';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MaterialApp(
    title: 'Grocery Store',
    theme: ThemeData(
      primarySwatch: Colors.green,
    ),
    home: AuthGate(),
  ));
}

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context,snapshot) {
        if(!snapshot.hasData){
          return SignInScreen(
            providerConfigs: [
              EmailProviderConfiguration()
            ],
          );
        }
       return MyHomePage(activeUser: FirebaseAuth.instance.currentUser);
      }
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({super.key, required this.activeUser});

  final User? activeUser;

  @override
  State<MyHomePage> createState() => _MyHomePageState(this.activeUser);
}

class _MyHomePageState extends State<MyHomePage> {

  int _index = 0;
  int _appBarindex = 0;
  bool appBarIcon = false;
  User? us;
  _MyHomePageState(this.us);

  @override
  Widget build(BuildContext context) {

    final pages = <Widget>[
      HomePage(activeUs: us,),
      CategoryPage(activeUs: us),
      CartPage(activeUs: us),
      OrdersPage(activeUs: us),
    ];

    final appBarPages = <Widget>[
      SearchPage(activeUs: us),
      ProfileScreen(
        providerConfigs: [
          EmailProviderConfiguration(),
        ],
        avatarSize: 100,
      )
    ];

    final pageItem = <BottomNavigationBarItem> [
      BottomNavigationBarItem(
          icon: Icon(Icons.home,color: Colors.green,),
          label: "Home",
      ),
      BottomNavigationBarItem(
          icon: Icon(Icons.category,color: Colors.green,),
          label: "Categories"
      ),
      BottomNavigationBarItem(
          icon: Icon(Icons.shopping_cart,color: Colors.green,),
          label: "Cart"
      ),
      BottomNavigationBarItem(
          icon: Icon(Icons.shopping_basket,color: Colors.green,),
          label: "Orders",
      ),

    ];

    final appBarTitle = <String>[
      "Home",
      "Categories",
      "Cart",
      "Orders",
    ];

    final appBarIconTitle = <String>[
      "Search",
      "Profile"
    ];

    final bottomNavBar = BottomNavigationBar(
      items: pageItem,
      currentIndex: _index,
      type: BottomNavigationBarType.fixed,
      onTap: (int index){
        setState(() {
          _index = index;
          appBarIcon = false;
        });
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarIcon?appBarIconTitle[_appBarindex]:appBarTitle[_index]),
        actions: [
          IconButton(
              onPressed:(){
                setState(() {
                  appBarIcon = true;
                  _appBarindex = 0;
                });
                },
              icon: Icon(Icons.search)
          ),
          IconButton(
              onPressed:(){
                setState(() {
                  appBarIcon = true;
                  _appBarindex = 1;
                });
              },
              icon: Icon(Icons.account_circle)
          ),
          PopupMenuButton(
            onSelected: (x){
              if (x=="lo"){
                FirebaseAuth.instance.signOut();
              }
            },
              itemBuilder: (BuildContext ctx){
                return [
                  PopupMenuItem(child: Text('Log Out'),value: "lo",),
                ];
              }
          )
        ],
      ),
      body: appBarIcon ? appBarPages[_appBarindex]:pages[_index],
      bottomNavigationBar: bottomNavBar,
    );
  }
}

class HomePage extends StatefulWidget {
  HomePage({super.key, required this.activeUs});

  final User? activeUs;

  @override
  State<HomePage> createState() => _HomePageState(this.activeUs);
}

class _HomePageState extends State<HomePage> {

  User? us;
  _HomePageState(this.us);

  final productsQuery = FirebaseFirestore.instance.collection('products');
  final cartInstance = FirebaseFirestore.instance.collection('cart');

  @override
  Widget build(BuildContext context) {
    return Container(
      child: FirestoreQueryBuilder<Map<String,dynamic>>(
        query: productsQuery,
        builder:(context, snapshot, _) {
          if (snapshot.isFetching) {
            return Center(child: CircularProgressIndicator(),) ;
          } else if (snapshot.hasError) {
            return Text('Something went wrong! ${snapshot.error}');
          }else if (snapshot.hasData){
            return GridView.builder(
              itemCount: snapshot.docs.length,
              itemBuilder: (context, index) {
                if (snapshot.hasMore && index + 1 == snapshot.docs.length) {
                  snapshot.fetchMore();
                }

                final product = snapshot.docs[index].data();

                return InkResponse(
                  onTap: (){
                    showModalBottomSheet<dynamic>(
                        isScrollControlled: true,
                        context: context,
                        builder: (context){
                          return Wrap(
                            children: [
                              Center(
                                child: Text(
                                  product['name'],
                                  style: TextStyle(
                                      fontSize: 50
                                  ),
                                ),
                              ),
                             Center(
                               child:  Container(
                                   child: Image.network(
                                     product['imgsrc'],
                                     fit: BoxFit.cover,
                                     height: 300,
                                     width: 300,
                                   )
                               ),
                             ),
                              ListTile(
                                leading: Text("Price:"),
                                trailing: Text("₹${product['price']}"),
                              ),
                              ListTile(
                                leading: Text("In Stock:"),
                                trailing: product['instock'] ? Text("Yes"):Text("No"),
                              ),
                              SizedBox(
                                  width: double.infinity,
                                  child:ElevatedButton(
                                      onPressed: (){

                                        if(product['instock']){
                                          String? uid = us?.uid;
                                          cartInstance.doc(uid).collection('items').add(product).whenComplete(() => Navigator.pop(context));
                                        }else{
                                          showDialog(context: context, builder: (context){
                                            return AlertDialog(
                                              title: Text("Attention !"),
                                              content: Text("Item Out Of Stock!"),
                                              actions: [
                                                TextButton(
                                                    onPressed: (){
                                                      Navigator.pop(context);
                                                    },
                                                    child: Text("Ok")
                                                )
                                              ],
                                            );
                                          });
                                        }

                                      },
                                      child: Text("Add to Cart")
                                  )
                              )
                            ],
                          );
                        });
                    },
                  enableFeedback: true,
                  child: GridTile(
                    child: Column(
                      children: [
                        Expanded(
                            flex: 2,
                            child: Image.network(
                              product['imgsrc'],
                              fit: BoxFit.cover,
                            )
                        ),
                        ListTile(
                          leading: Text(product['name']),
                        ),
                      ],
                    ),
                  ),
                );
              },
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
            );
          }else{
            return Center(child: Text('Error!'),);
          }
        } ,
      )
    );
  }
}

class CategoryPage extends StatefulWidget {
  CategoryPage({super.key, required this.activeUs});

  final User? activeUs;
  
  @override
  State<CategoryPage> createState() => _CategoryPageState(this.activeUs);
}

class _CategoryPageState extends State<CategoryPage> {

  User? us;
  _CategoryPageState(this.us);

  final categoryQuery = FirebaseFirestore.instance.collection('products');
  final cartInstance = FirebaseFirestore.instance.collection('cart');

  List<String> cat = [];

  Future<void> getCat() async {
    await categoryQuery.get().then((value) {
      for (var doc in value.docs){
        if (!cat.contains(doc['cat'])){
          setState(() {
            cat.add(doc['cat']);
          });
        }
      }
    });

    await categoryQuery.snapshots().listen((event) {
      for (var doc in event.docs){
        if (!cat.contains(doc['cat'])){
          setState(() {
            cat.add(doc['cat']);
          });
        }
      }
    });
  }

  Future<void> showProductsInCategory(String category) async {
    showModalBottomSheet<dynamic>(
        isScrollControlled: true,
        context: context,
        builder: (context){
          return Wrap(
            children: [
              Container(
                child: Center(
                  child: Text(
                      "$category",
                      style: TextStyle(
                          fontSize: 50
                      )
                  ),
                ),
              ),
              Container(
                height: 200,
                child: FirestoreListView<Map<String, dynamic>>(
                  query: categoryQuery.where('cat',isEqualTo: category),
                  itemBuilder:(context, snapshot) {
                    Map<String, dynamic> categoryItem = snapshot.data();

                    return ListTile(
                      title: Text(categoryItem['name']),
                      subtitle: Text("Price: ${categoryItem['price']}"),
                      trailing: TextButton(
                        child: Text("ADD"),
                        onPressed: (){
                          if(categoryItem['instock']){
                            String? uid = us?.uid;
                            cartInstance.doc(uid).collection('items').add(categoryItem).whenComplete(() => Navigator.pop(context));
                          }else{
                            showDialog(context: context, builder: (context){
                              return AlertDialog(
                                title: Text("Attention !"),
                                content: Text("Item Out Of Stock!"),
                                actions: [
                                  TextButton(
                                      onPressed: (){
                                        Navigator.pop(context);
                                      },
                                      child: Text("Ok")
                                  )
                                ],
                              );
                            });
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              Container(
                  width: double.infinity,
                  child: ElevatedButton(
                    child: Text("CLOSE"),
                    onPressed: (){
                      Navigator.pop(context);
                    },
                  )
              )
            ],
          );
        }
    );
  }

  @override
  void initState() {
    super.initState();
    cat.clear();
    getCat();

  }

  @override
  void dispose() {
    super.dispose();
    cat.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: cat.isNotEmpty ? ListView.builder(
          itemCount: cat.length,
          itemBuilder: (context, index){
            return ListTile(
              title: Text(cat[index]),
              onTap: (){
                showProductsInCategory(cat[index]);
              },
            );
          }
      ): Center(child: CircularProgressIndicator(),),
    );
  }
}

class CartPage extends StatefulWidget {
  CartPage({super.key, required this.activeUs});

  final User? activeUs;

  @override
  State<CartPage> createState() => _CartPageState(this.activeUs);
}

class _CartPageState extends State<CartPage> {

  User? us;
  _CartPageState(this.us);

  @override
  Widget build(BuildContext context) {

    String? uid = us?.uid;
    final cartQuery = FirebaseFirestore.instance.collection('cart').doc(uid).collection('items');
    final orderQuery = FirebaseFirestore.instance.collection('orders');

    Future<void> deleteDocs() async {
      showAlertDialog(BuildContext context){
        AlertDialog alert=AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              Container(
                  margin: EdgeInsets.only(left: 5),
                  child:Text("Loading" )
              ),
            ],
          ),
        );
        showDialog(barrierDismissible: false,
          context:context,
          builder:(BuildContext context){
            return alert;
          },
        );
      }
      showAlertDialog(context);
      var cartDelete = cartQuery;
      await cartDelete.get().then((value) {
        for (var doc in value.docs){
          doc.reference.delete();
        }
      }).whenComplete(() {
        Navigator.pop(context);
      });
    }

    return Container(
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: (){
                  deleteDocs();
                },
                child: Text("Clear All")
            ),
          ),
          Expanded(
              child: FirestoreListView<Map<String,dynamic>>(
                query: cartQuery,
                itemBuilder: (context,snapshot){
                  Map<String, dynamic> items = snapshot.data();

                  return ListTile(
                    leading: Text("${items['name']}"),
                    trailing: Text("${items['price']}"),
                  );
                },
              )
          ),
          SizedBox(
            width: double.infinity,
            child: FirestoreQueryBuilder<Map<String, dynamic>>(
              query: cartQuery,
              builder: (context, snapshot, _) {
                if (snapshot.isFetching) {
                  return Text("Loading");
                }
                if (snapshot.hasError) {
                  return Text('Something went wrong! ${snapshot.error}');
                }

                double cartTotal = 0;
                List<Map<String,dynamic>> orderItems = [];
                orderItems.clear();
                for(var doc in snapshot.docs){
                  orderItems.add(doc.data());
                  cartTotal += doc.data()['price'].toDouble();
                }

                return ElevatedButton(
                    onPressed: (){

                      if (cartTotal == 0){
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Your Cart is Empty!"))
                        );
                      }else{
                        var uuid = Uuid();
                        String orderId = uuid.v4();
                        Timestamp ts = Timestamp.now();
                        String finalord = ts.seconds.toString()+'-'+orderId.substring(0,8);

                        orderQuery.doc(uid).collection('order').add({
                          'orderid': finalord,
                          'total':cartTotal,
                          'status':'placed',
                          'placedTime': ts
                        }).then((value) {
                          orderItems.forEach((element) {
                            orderQuery.doc(uid).collection('order')
                                .doc(value.id)
                                .collection('items')
                                .add(element).whenComplete(() {
                              orderItems.clear();
                              deleteDocs();
                            });
                          });
                        });
                      }
                    },
                    child: snapshot.docs.length == null ? Text("Loading"): Text("Checkout ${cartTotal}")
                );
              },
            )
          ),
        ],
      ),
    );
  }
}

class OrdersPage extends StatefulWidget {
  OrdersPage({super.key, required this.activeUs});

  final User? activeUs;

  @override
  State<OrdersPage> createState() => _OrdersPageState(this.activeUs);
}

class _OrdersPageState extends State<OrdersPage> {

  User? us;
  _OrdersPageState(this.us);

  @override
  Widget build(BuildContext context) {

    String? uid = us?.uid;
    final orderQuery = FirebaseFirestore.instance.collection('orders').doc(uid).collection('order');

    return Container(
      child: FirestoreListView<Map<String, dynamic>>(
        query: orderQuery.orderBy('placedTime',descending: true),
        itemBuilder: (context, snapshot) {

          Map<String, dynamic> user = snapshot.data();
          Timestamp ts = user['placedTime'];
          DateTime placedAt =  DateTime.fromMillisecondsSinceEpoch(ts.millisecondsSinceEpoch);

          Future<void> orderDetails() async {
            showModalBottomSheet<dynamic>(
                isScrollControlled: true,
                context: context,
                builder: (context){
                  return Wrap(
                      children: [
                        Container(
                          child: Center(
                            child: Text(
                                "Order Items",
                                style: TextStyle(
                                    fontSize: 50
                                )
                            ),
                          ),
                        ),
                        Container(
                          height: 200,
                          child: FirestoreListView<Map<String, dynamic>>(
                              query: orderQuery.doc(snapshot.id).collection('items'),
                              itemBuilder:(context, snapshot) {
                                Map<String, dynamic> orderItem = snapshot.data();
                                return ListTile(
                                  title: Text(orderItem['name']),
                                );
                              },
                          ),
                        ),
                        Container(
                          child: Center(
                            child: Text(
                                "Total: ₹ ${user['total']}",
                              style: TextStyle(
                                fontSize: 25
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                            child: ElevatedButton(
                              child: Text("CLOSE"),
                              onPressed: (){
                                Navigator.pop(context);
                              },
                            )
                        )
                      ],
                  );
                }
                );
          }
          return ListTile(
            title: Text(user['orderid']),
            subtitle: Text('Placed At: ${placedAt.day}/${placedAt.month}/${placedAt.year} ${placedAt.hour}:${placedAt.minute}:${placedAt.second}'),
            trailing: Text(user['status']),
            onTap: (){
              orderDetails();
            },
          );
        },
      ),
    );
  }
}

class SearchPage extends StatefulWidget {
  SearchPage({super.key, required this.activeUs});

  final User? activeUs;

  @override
  State<SearchPage> createState() => _SearchPageState(this.activeUs);
}

class _SearchPageState extends State<SearchPage> {

  User? us;
  _SearchPageState(this.us);

  final productsQuery = FirebaseFirestore.instance.collection('products');
  final cartInstance = FirebaseFirestore.instance.collection('cart');

  String searchValue = "";

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          Container(
              width: double.infinity,
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search",
                ),
                onChanged: (text){
                  setState(() {
                    searchValue = text;
                    searchValue.isNotEmpty ? searchValue = searchValue.replaceFirst(searchValue[0], searchValue[0].toUpperCase()): searchValue = "";
                  });
                },
              )
          ),
          Expanded(
              child: Container(
                child: searchValue.isNotEmpty? FirestoreListView<Map<String, dynamic>>(
                  query: productsQuery.where('name',isGreaterThanOrEqualTo: searchValue).where('name',isLessThanOrEqualTo: '${searchValue}\uf8ff'),
                  itemBuilder:(context, snapshot) {
                    Map<String, dynamic> searchItem = snapshot.data();
                    return ListTile(
                      title: Text(searchItem['name']),
                      subtitle: Text("Price: ${searchItem['price']}"),
                      trailing: TextButton(
                        child: Text("ADD"),
                        onPressed: (){
                          String? uid = us?.uid;
                          if(searchItem['instock']){
                            cartInstance.doc(uid).collection('items').add(searchItem).whenComplete(() {
                              showAlertDialog(BuildContext context){
                                AlertDialog alert=AlertDialog(
                                  title: Text("Product Added to Cart!"),
                                  actions: [
                                    TextButton(
                                        onPressed: (){
                                          Navigator.pop(context);
                                        },
                                        child: Text('OK')
                                    )
                                  ],
                                );
                                showDialog(barrierDismissible: true,
                                  context:context,
                                  builder:(BuildContext context){
                                    return alert;
                                  },
                                );
                              }
                              showAlertDialog(context);
                            });
                          }else{
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Item Out of Stock!"))
                            );
                          }
                        },
                      ),
                    );
                  },
                ): Center(child: Text("Enter A Product Name"),),
              )
          ),
        ],
      ),
    );
  }
}
