class WordAssociation {
  final List<String> transcribedWords;
  final String? realWord;
  final List<double> transcribedWordsProbabilities;

  WordAssociation(this.transcribedWords, this.realWord, this.transcribedWordsProbabilities);

  @override
  String toString() {
    return 'WordAssociation{transcribedWords: $transcribedWords, realWord: $realWord, transcribedWordsProbabilities: $transcribedWordsProbabilities}';
  }
}