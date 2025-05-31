import 'package:index/models/genre.dart';
import 'package:index/models/person.dart';

class Movie {
  bool adult;
  String backdropPath;
  List<int>? genreIds;
  List<Genre>? genres;
  int id;
  String originalLanguage;
  String originalTitle;
  String overview;
  double popularity;
  String posterPath;
  String releaseDate;
  String title;
  bool video;
  double voteAverage;
  int voteCount;
  int? duration;
  Duration? creditsStart;
  bool? isRecentlyWatched;
  int? watchedProgress;
  String? trailerUrl;
  List<Person>? cast;

  Movie({
    required this.adult,
    required this.backdropPath,
    this.genreIds,
    this.genres,
    required this.id,
    required this.originalLanguage,
    required this.originalTitle,
    required this.overview,
    required this.popularity,
    required this.posterPath,
    required this.releaseDate,
    required this.title,
    required this.video,
    required this.voteAverage,
    required this.voteCount,
    this.duration,
    this.creditsStart,
    this.isRecentlyWatched,
    this.watchedProgress,
    this.trailerUrl,
    this.cast,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      adult: json['adult'],
      backdropPath: json['backdrop_path'] ?? '',
      genreIds: json['genre_ids'] != null ? List<int>.from(json['genre_ids']) : null,
      genres: json['genres'] != null ? List<Genre>.from(json['genres'].map((json) => Genre.fromJson(json)).toList()) : null,
      id: json['id'],
      originalLanguage: json['original_language'],
      originalTitle: json['original_title'],
      overview: json['overview'],
      popularity: double.parse((json['popularity'].toDouble() ?? 0.0).toStringAsFixed(1)),
      posterPath: json['poster_path'] ?? '',
      releaseDate: json['release_date'],
      title: json['title'],
      video: json['video'],
      voteAverage: double.parse((json['vote_average'].toDouble() ?? 0.0).toStringAsFixed(1)),
      voteCount: json['vote_count'] ?? 0,
    );
  }
}