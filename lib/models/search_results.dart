import 'package:index/models/movie.dart';
import 'package:index/models/person.dart';
import 'package:index/models/tv_show.dart';
import 'package:index/utils/enums.dart';

class SearchResults {
  int page;
  int totalPages;
  int totalResults;
  List<Movie>? movies;
  List<TvShow>? tvShows;
  List<Person>? cast;

  SearchResults({
    required this.page,
    required this.totalPages,
    required this.totalResults,
    this.movies,
    this.tvShows,
    this.cast,
  });

  factory SearchResults.fromJson(PageType? pageType, Map<String, dynamic> json) {
    List<Movie>? movies;
    List<TvShow>? tvShows;
    List<Person>? cast;

    if (pageType != null) {
      List results = json['results'] as List;
      if (pageType == PageType.movies) {
        movies = results.map((json) => Movie.fromJson(json)).toList();
      } else {
        tvShows = results.map((json) => TvShow.fromJson(json)).toList();
      }
    } else {
      List results = json['cast'] as List;
      List<Person> allCast = results.map((json) => Person.fromJson(json)).toList();
      cast = allCast.where((person) => person.department == 'Acting').toList();
    }

    return SearchResults(
      page: json['page'],
      totalPages: json['total_pages'],
      totalResults: json['total_results'],
      movies: movies,
      tvShows: tvShows,
      cast: cast,
    );
  }
}
