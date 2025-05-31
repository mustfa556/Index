import 'package:index/models/genre.dart';
import 'package:index/models/person.dart';

class TvShow {
  bool adult;
  String backdropPath;
  List<int>? genreIds;
  List<Genre>? genres;
  int id;
  String originalLanguage;
  String originalName;
  String overview;
  double popularity;
  String posterPath;
  String firstAirDate;
  String name;
  double voteAverage;
  int voteCount;
  String? trailerUrl;
  List<Season>? seasons;
  List<Person>? cast;

  TvShow({
    required this.adult,
    required this.backdropPath,
    this.genreIds,
    this.genres,
    required this.id,
    required this.originalLanguage,
    required this.originalName,
    required this.overview,
    required this.popularity,
    required this.posterPath,
    required this.firstAirDate,
    required this.name,
    required this.voteAverage,
    required this.voteCount,
    this.trailerUrl,
    this.seasons,
    this.cast,
  });

  factory TvShow.fromJson(Map<String, dynamic> json) {
    return TvShow(
      adult: json['adult'],
      backdropPath: json['backdrop_path'] ?? '',
      genreIds: json['genre_ids'] != null ? List<int>.from(json['genre_ids']) : null,
      genres: json['genres'] != null ? List<Genre>.from(json['genres'].map((json) => Genre.fromJson(json)).toList()) : null,
      id: json['id'],
      originalLanguage: json['original_language'],
      originalName: json['original_name'],
      overview: json['overview'],
      popularity: double.parse((json['popularity'].toDouble() ?? 0.0).toStringAsFixed(1)),
      posterPath: json['poster_path'] ?? '',
      firstAirDate: json['first_air_date'],
      name: json['name'],
      voteAverage: double.parse((json['vote_average'].toDouble() ?? 0.0).toStringAsFixed(1)),
      voteCount: json['vote_count'] ?? 0,
      seasons: json['seasons'] != null ? List<Season>.from(json['seasons'].map((json) => Season.fromJson(json)).toList()) : null,
    );
  }
}

class Season {
  int id;
  int number;
  String name;
  String? airDate;
  List<Episode>? episodes;

  Season({
    required this.id,
    required this.number,
    required this.name,
    required this.airDate,
    this.episodes,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      id: json['id'],
      number: json['season_number'],
      name: json['name'],
      airDate: json['air_date'],
    );
  }
}

class Episode {
  int id;
  int tvShowId;
  String tvShowName;
  int number;
  int season;
  String name;
  String overview;
  String stillPath;
  int duration;
  Duration? creditsStart;
  String? airDate;
  bool isRecentlyWatched;
  int? watchedProgress;

  Episode({
    required this.id,
    required this.tvShowId,
    required this.tvShowName,
    required this.number,
    required this.season,
    required this.name,
    required this.overview,
    required this.stillPath,
    required this.duration,
    this.creditsStart,
    this.airDate,
    this.isRecentlyWatched = false,
    this.watchedProgress,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id'],
      tvShowId: json['show_id'],
      tvShowName: json['show_name'],
      number: json['episode_number'],
      season: json['season_number'],
      name: json['name'],
      overview: json['overview'],
      stillPath: json['still_path'] ?? '',
      duration: json['runtime'] ?? 0,
      airDate: json['air_date'],
    );
  }
}