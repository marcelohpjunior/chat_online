import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

void main() async{
  runApp(MyApp());
}

final COLLECTION_NAME = "menssages";

final ThemeData kIOSTtheme = ThemeData(
    primaryColor: Colors.orange,
    primarySwatch: Colors.grey[100],
    primaryColorBrightness: Brightness.light);

final ThemeData kDefaultTheme = ThemeData(
  primaryColor: Colors.purple,
  accentColor: Colors.orange[400],
  cursorColor: Colors.purple,
  primarySwatch: Colors.purple,
  primaryColorBrightness: Brightness.light,
  tabBarTheme: TabBarTheme(labelColor: Colors.white),
);

final googleSignIn = GoogleSignIn();
final auth = FirebaseAuth.instance;

Future<Null> _ensureLoggedIn() async {
  GoogleSignInAccount user = googleSignIn.currentUser;
  if (user == null) {
    user = await googleSignIn.signInSilently();
  }
  if (user == null) {
    user = await googleSignIn.signIn();
  }

  if (await auth.currentUser() == null) {
    GoogleSignInAuthentication credentials =
        await googleSignIn.currentUser.authentication;
    await auth.signInWithGoogle(
        idToken: credentials.idToken, accessToken: credentials.accessToken);
  }
}

_handleSubmited(String text) async {
  await _ensureLoggedIn();
  _sendMenssage(text: text);
}

_sendMenssage({String text, String imgUrl}) {
  Firestore.instance.collection(COLLECTION_NAME).add({
    "text": text,
    "imgUrl": imgUrl,
    "senderName": googleSignIn.currentUser.displayName,
    "senderPhotoUrl": googleSignIn.currentUser.photoUrl
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Chat Online",
      debugShowCheckedModeBanner: false,
      theme: Theme.of(context).platform == TargetPlatform.iOS
          ? kIOSTtheme
          : kDefaultTheme,
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      top: false,
      child: Scaffold(
        appBar: AppBar(
            title: Text(
              "Chat Online",
              style: TextStyle(color: Colors.white),
            ),
            centerTitle: true,
            elevation:
                Theme.of(context).platform == TargetPlatform.iOS ? 0.0 : 4.0),
        body: Column(
          children: <Widget>[
            Expanded(
                child: StreamBuilder(
                    stream: Firestore.instance.collection(COLLECTION_NAME).snapshots(),
                    builder: (context, snapshot) {
                      switch (snapshot.connectionState) {
                        case ConnectionState.none:
                        case ConnectionState.waiting:
                          return Center(
                            child: CircularProgressIndicator(),
                          );
                        default:
                          return ListView.builder(
                              reverse: true,
                              itemCount: snapshot.data.documents.length,
                              itemBuilder: (context, index) {
                                List r = snapshot.data.documents.reversed.toList();
                                return ChatMenssage(r[index].data);
                              }
                          );
                      }
                    })),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
              ),
              child: TextComposer(),
            ),
          ],
        ),
      ),
    );
  }
}

class TextComposer extends StatefulWidget {
  @override
  _TextComposerState createState() => _TextComposerState();
}

class _TextComposerState extends State<TextComposer> {
  final _textController = TextEditingController();
  bool _isComposing = false;

  void _reset() {
    _textController.clear();
    setState(() {
      _isComposing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).accentColor),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: Theme.of(context).platform == TargetPlatform.iOS
            ? BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200])))
            : null,
        child: Row(
          children: <Widget>[
            Container(
              child: IconButton(icon: Icon(Icons.camera_alt), onPressed: () async {
                await _ensureLoggedIn();
                File imgFile = await ImagePicker.pickImage(source: ImageSource.camera);
                if(imgFile == null)
                  return;

                StorageUploadTask task = FirebaseStorage.instance.ref().
                child(googleSignIn.currentUser.id.toString() +
                    DateTime.now().millisecondsSinceEpoch.toString()).putFile(imgFile);
                StorageTaskSnapshot taskSnapshot = await task.onComplete;
                String url = await taskSnapshot.ref.getDownloadURL();
                _sendMenssage(imgUrl: url);
              }),
            ),
            Expanded(
                child: TextField(
              controller: _textController,
              decoration:
                  InputDecoration.collapsed(hintText: "Enviar uma mensagem..."),
              onChanged: (text) {
                setState(() {
                  _isComposing = text.length > 0;
                });
              },
              onSubmitted: (text) {
                _handleSubmited(text);
                _reset();
              },
            )),
            Container(
              child: Theme.of(context).platform == TargetPlatform.iOS
                  ? CupertinoButton(
                      child: Text(
                        "Enviar",
                      ),
                      onPressed: _isComposing
                          ? () {
                              _handleSubmited(_textController.text);
                              _reset();
                            }
                          : null,
                    )
                  : IconButton(
                      icon: Icon(Icons.send),
                      onPressed: _isComposing
                          ? () {
                              _handleSubmited(_textController.text);
                              _reset();
                            }
                          : null),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMenssage extends StatelessWidget {
  final Map<String, dynamic> data;

  ChatMenssage(this.data);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: NetworkImage(data["senderPhotoUrl"]),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  data["senderName"],
                  style: Theme.of(context).textTheme.subhead,
                ),
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  child: data["imgUrl"] != null
                      ? Image.network(
                          data["imgUrl"],
                          width: 250,
                        )
                      : Text(data["text"]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
