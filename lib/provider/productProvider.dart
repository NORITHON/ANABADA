import 'dart:io' as io;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ProductProvider extends ChangeNotifier{

  ProductProvider(){
    init();
  }
  // Get a non-default Storage bucket
  late FirebaseStorage storage;
  late Reference storageRef;
  CollectionReference products = FirebaseFirestore.instance.collection('products');
  void init(){
    storage = FirebaseStorage.instance;
    storageRef = storage.ref().child("image");
  }

  List<Product> _productList = [];

  List<Product> getProductList(){
    return _productList;
  }

  bool _noP = true;
  bool getNoProduct() => _noP;

  Future<void> getProducts(String uid) async{
    print(uid);
    await products.doc(uid).collection("product").get().then((value){
      if(value.size == 0){
        _noP = true;
      }
      else{
        _noP = false;
        List _list = value.docs.map((sd){}).toList();
        _productList.clear();
        for(int i = 0 ; i < _list.length ; i++){
          _productList.add(Product(
              category: _list[i]["category"],
              name: _list[i]["name"],
              productName: _list[i]["productName"],
              url: _list[i]["fileUrl"],
              text: _list[i]["text"],
              address: _list[i]["address"]
          ));
        }

      }
    }
    );
    notifyListeners();
  }

  Future<UploadTask?> uploadFile(XFile? file) async {
    if (file == null) {
      return null;
    }

    UploadTask uploadTask;

    // Create a Reference to the file
    Reference ref = FirebaseStorage.instance
        .ref()
        .child('productImage')
        .child('/${file.name}.${file.mimeType}');

    final metadata = SettableMetadata(
      contentType: 'image/${file.mimeType}',
      customMetadata: {'picked-file-path': file.path},
    );

    if (kIsWeb) {
      uploadTask = ref.putData(await file.readAsBytes(), metadata);
    } else {
      uploadTask = ref.putFile(io.File(file.path), metadata);
    }

    return Future.value(uploadTask);
  }


  Future<void> addProduct(XFile? file, Product product, String uid) async{
    String? fileUrl = "";
    if(file != null){
      UploadTask? uploadTask = await uploadFile(file);
      io.sleep(const Duration(seconds: 2));
      fileUrl = await uploadTask!.snapshot.ref.getDownloadURL();
    }
    await products.doc(uid).collection("product").doc().set(<String, dynamic>{
      "fileUrl" : fileUrl,
      "name" : product.name,
      "productName" : product.productName,
      "text" : product.text,
      "category" : product.category,
      "address" : product.address,

    }).then((value){

    }).onError((error, stackTrace) => null);
  }


  Future<void> _downloadFile(Reference ref, BuildContext context) async {
    final io.Directory systemTempDir = io.Directory.systemTemp;
    final io.File tempFile = io.File('${systemTempDir.path}/temp-${ref.name}');
    if (tempFile.existsSync()) await tempFile.delete();

    await ref.writeToFile(tempFile);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Success!\n Downloaded ${ref.name} \n from bucket: ${ref.bucket}\n '
              'at path: ${ref.fullPath} \n'
              'Wrote "${ref.fullPath}" to tmp-${ref.name}',
        ),
      ),
    );
  }

  Future<String> uploadImage(String imageName) async {
    final _firebaseStorage = FirebaseStorage.instance;
    final _imagePicker = ImagePicker();
    PickedFile? image;
    //Check Permissions
    await Permission.photos.request();
    var permissionStatus = await Permission.photos.status;
    if (permissionStatus.isGranted){
      //Select Image
      image = await _imagePicker.getImage(source: ImageSource.gallery);
      if (image != null){
        var file = XFile(image.path);
        //Upload to Firebase
        String url;
        var snapshot = await _firebaseStorage.ref()
            .child('images/$imageName')
            .putFile(io.File(image.path));
        url = await snapshot.ref.getDownloadURL();
        return url;
      } else {
        print('No Image Path Received');
        return "";
      }
    } else {
      print('Permission not granted. Try Again with permission access');
      return "-1";
    }
  }
}


class Product {
  const Product({
    required this.category,
    required this.name,
    required this.productName,
    required this.url,
    required this.text,
    required this.address,
  });

  final String category;
  final String name;
  final String productName;
  final String url;
  final String text;
  final String address;
}