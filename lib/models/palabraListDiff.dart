import 'package:diffutil_dart/diffutil.dart' as diffutil;
import 'package:transcriber_whisper/models/palabra.dart';

class PalabraListDiff extends diffutil.ListDiffDelegate<Palabra> {
  PalabraListDiff(List<Palabra> oldList, List<Palabra> newList)
      : super(oldList, newList);

  @override
  bool areContentsTheSame(int oldItemPosition, int newItemPosition) {
    // Compara el contenido de las palabras
    return oldList[oldItemPosition].texto == newList[newItemPosition].texto;
  }

  @override
  bool areItemsTheSame(int oldItemPosition, int newItemPosition) {
    // Compara si son la misma palabra (por ejemplo, por índice)
    return oldList[oldItemPosition].index == newList[newItemPosition].index;
  }
}