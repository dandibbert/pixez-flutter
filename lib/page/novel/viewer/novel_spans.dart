import 'package:pixez/models/novel_web_response.dart';

enum NovelSpansType {
  normal,
  newPage,
  pixivImage,
  uploadedImage,
  jumpUri,
  rb,
  chapter,
  jump,
}

class NovelSpansData {
  final NovelSpansType type;
  final String text;

  NovelSpansData(this.type, this.text);
}

class PixivImageSpanData extends NovelSpansData {
  final int illustId;
  final int targetIndex;
  final NovelIllusts illust;

  PixivImageSpanData(this.illustId, this.targetIndex, String text, this.illust)
    : super(NovelSpansType.pixivImage, text);
}
