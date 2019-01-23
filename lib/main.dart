import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:simple_permissions/simple_permissions.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: "Generated App",
      theme: new ThemeData(
        primarySwatch: Colors.pink,
        primaryColor: const Color(0xFFe91e63),
        accentColor: const Color(0xFFe91e63),
        canvasColor: const Color(0xFFfafafa),
      ),
      home: new MyImagePage(),
    );
  }
}

// 画面を構成するウィジェット類、FAB/Drawerの処理など、グラフィックの描画以外の処理をまかなうクラス
class MyImagePage extends StatefulWidget {

  @override
  _MyImagePageState createState() => new _MyImagePageState();
}

class _MyImagePageState extends State<MyImagePage> {

  File image;
  GlobalKey _homeStateKey = GlobalKey();
  List<List<Offset>> strokes = new List<List<Offset>>();
  MyPainter _painter;
  ui.Image targetImage;
  Size mediasize;

  double _r = 255.0;
  double _g = 0.0;
  double _b = 0.0;

  _MyImagePageState() {
    requestPermissions();
  }

  // パーミッションの設定
  void requestPermissions() async {
    // simple_permissionsパッケージのSimplePermissionsを利用
    // 許可されている場合には自動的に出さないようになっているっぽい
    // カメラと外部ストレージの保存のパーミッション
    await SimplePermissions.requestPermission(
      Permission.Camera);
    await SimplePermissions.requestPermission(
      Permission.WriteExternalStorage);
  }

  @override
  Widget build(BuildContext context) {
    mediasize = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: Text("Canture Image Drawing!"),
      ),

      body: Listener(
        // タップ処理のためにListenerウィジェットを使用
        onPointerDown: _pointerDown,
        onPointerMove: _pointerMove,
        child: Container(
          child: CustomPaint(
            key: _homeStateKey,
            painter: _painter,
            child: ConstrainedBox(
                constraints: BoxConstraints.expand()),
          ),
        ),
      ),

      // メンバに撮影した画像を保持して、それに応じたFABアイコンを表示する
      floatingActionButton: image == null
        ? FloatingActionButton(
          onPressed: getImage,
          tooltip: "take a picture!",
          child: Icon(Icons.add_a_photo))
        : FloatingActionButton(
          onPressed: saveImage,
          tooltip: "Save Image",
          child: Icon(Icons.save),
      ),
      drawer: Drawer(
        child: Center(
          child: Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(10.0),
                child: Text("Set Color...",
                  style: TextStyle(fontSize: 20.0),),
              ),

              Padding (
                padding: EdgeInsets.all(10.0),
                // スライダーを0~255で設定する
                // valueはメンバを入れる
                // タップされたらsetState()でメンバを更新してUIアップデート
                child: Slider(min: 0.0, max: 255.0, value: _r,
                  onChanged: sliderR,),
              ),

              Padding(
                padding: EdgeInsets.all(10.0),
                child: Slider(min: 0.0, max: 255.0, value: _g,
                  onChanged: sliderG,),
              ),

              Padding(
                padding: EdgeInsets.all(10.0),
                child: Slider(min: 0.0, max: 255.0, value: _b,
                  onChanged: sliderB,),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void sliderR(double value) {
    setState(() {
      _r = value;
    });
  }

  void sliderG(double value) {
    setState(() {
      _g = value;
    });
  }

  void sliderB(double value) {
    setState(() {
      _b = value;
    });
  }

  // MyPointerの作成
  void createMyPointer() {
    // RGB値を使ってインスタンス生成
    var strokeColor = Color.fromARGB(200, _r.toInt(), _g.toInt(), _b.toInt());
    _painter = MyPainter(targetImage, image, strokes, mediasize, strokeColor);
  }

  // カメラを起動しイメージを読み込む
  void getImage() async {
    // カメラを起動してそのイメージファイルを取得する
    // image_pickerパッケージのpickImage()を使用
    File file = await ImagePicker.pickImage(source: ImageSource.camera);
    image = file;
    // 画像の読み込み
    loadImage(image.path);
  }

  // イメージの保存
  void saveImage() {
    // 実際の保存処理はMyPainter側で行なっている
    _painter.saveImage();
    showDialog(context: context, builder: (BuildContext context) => AlertDialog(
      title: Text("Saved!"),
      content: Text("save image to file."),
    ));
  }

  // パスからイメージを読み込みui.Imageを作成する
  // FileクラスからImageを取り出す
  void loadImage(path) async {
    // バイトデータをint配列として取り出す
    List<int> byts = await image.readAsBytes();
    // リストをUint8Listクラスに変換する
    Uint8List u8lst = Uint8List.fromList(byts);
    // instantiateImageCodecでui.Imageを取り出す
    ui.instantiateImageCodec(u8lst).then((codec) {
      codec.getNextFrame().then(
          (frameInfo) {
            targetImage = frameInfo.image;
            setState(() {
              createMyPointer();
            });
          }
      );
    });
  }

  // タップした時の処理
  void _pointerDown(PointerDownEvent event) {
    RenderBox referenceBox = _homeStateKey.currentContext.findRenderObject();
    strokes.add([referenceBox.globalToLocal(event.position)]);

    setState(() {
      createMyPointer();
    });
  }

  // ドラッグ中の処理
  void _pointerMove(PointerMoveEvent event) {
    // renderBoxを取得
    RenderBox referenceBox = _homeStateKey.currentContext.findRenderObject();
    // event.positionでイベント発生箇所をstrokeに追加
    strokes.last.add(referenceBox.globalToLocal(event.position));

    setState(() {
      // _painterを更新してウィジェットアップデート
      createMyPointer();
    });
  }
}

// ペインタークラス
// 描画処理、イメージの保存処理などをまかなうクラス
class MyPainter extends CustomPainter {
  File image;
  ui.Image targetImage;
  // 画像サイズのSize
  Size mediasize;
  // 描画の色
  Color strokecolor;
  // タップ情報がまとめられたリスト
  var strokes = new List<List<Offset>>();

  // コンストラクタ
  MyPainter(this.targetImage, this.image, this.strokes, this.mediasize, this.strokecolor);

  @override
  //
  void paint(Canvas canvas, Size size) {
    mediasize = size;
    ui.Image im = drawToCanvas();
    canvas.drawImage(im, Offset(0.0, 0.0), Paint());
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;

  // 描画イメージをファイルに保存する
  void saveImage() async {
    ui.Image img = drawToCanvas();

    // pngファイルのbytedataを取得
    final ByteData bytedata = await img.toByteData(
      format: ui.ImageByteFormat.png);
    // 現在のタイムスタンプの値を取得
    int epoch = new DateTime.now().millisecondsSinceEpoch;
    // タイムスタンプを名前としたFileを生成する
    final file = new File(image.parent.path + "/" + epoch.toString() + ".png");
    // データを書き出す
    file.writeAsBytes(bytedata.buffer.asUint8List());
  }

  // イメージを描画したui.Imageを返す
  // PictureRecorderクラスを使い、あらたに用意したCanvasに描いていく
  // 完成したイメージをui.Imageとして返す役割
  ui.Image drawToCanvas() {
    // 文字通りのグラフィックの描画を記録するためのPictureRecorderクラス
    ui.PictureRecorder recorder = ui.PictureRecorder();
    // 作成されたCanvasの描画処理がrecorderに記録されていく
    ui.Canvas canvas = Canvas(recorder);

    Paint p1 = Paint();
    p1.color = Colors.white;
    canvas.drawColor(Colors.white, BlendMode.color);

    if (targetImage != null) {
      Rect r1 = Rect.fromPoints(Offset(0.0, 0.0),
          Offset(targetImage.width.toDouble(), targetImage.height.toDouble()));

      Rect r2 = Rect.fromPoints(Offset(0.0, 0.0),
          Offset(mediasize.width, mediasize.height));

      Paint p2 = new Paint();
      p2.color = strokecolor;
      p2.style = PaintingStyle.stroke;
      p2.strokeWidth = 5.0;

      for (var stroke in strokes) {
        Path strokePath = new Path();
        strokePath.addPolygon(stroke, false);
        canvas.drawPath(strokePath, p2);
      }

      // 描画処理の記録を終了して記録されたPictureクラスを取得
      ui.Picture picture = recorder.endRecording();
      // ui.Imageクラスに変換してreturn
      return picture.toImage(mediasize.width.toInt(), mediasize.height.toInt());
    }
  }
}
