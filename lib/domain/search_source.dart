class SearchSource {
  const SearchSource({
    required this.title,
    required this.url,
    required this.summary,
  });
  final String title, url, summary;
  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    'summary': summary,
  };
  factory SearchSource.fromJson(Map<String, dynamic> data) => SearchSource(
    title: data['title'] as String? ?? '',
    url: data['url'] as String? ?? '',
    summary: data['summary'] as String? ?? '',
  );
}
