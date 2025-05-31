import 'package:flutter/material.dart';

class Urls {
  static const String tmdbBase = 'https://api.themoviedb.org/3';
  static const String searchMovies = '$tmdbBase/search/movie';
  static const String searchTvShows = '$tmdbBase/search/tv';
  static const String imageBase_w45 = 'https://image.tmdb.org/t/p/w45';
  static const String imageBase_w92 = 'https://image.tmdb.org/t/p/w92';
  static const String imageBase_w154 = 'https://image.tmdb.org/t/p/w154';
  static const String imageBase_w185 = 'https://image.tmdb.org/t/p/w185';
  static const String imageBase_w300 = 'https://image.tmdb.org/t/p/w300';
  static const String imageBase_w342 = 'https://image.tmdb.org/t/p/w342';
  static const String imageBase_w500 = 'https://image.tmdb.org/t/p/w500';
  static const String imageBase_w632 = 'https://image.tmdb.org/t/p/w632';
  static const String imageBase_w780 = 'https://image.tmdb.org/t/p/w780';
  static const String imageBase_w1280 = 'https://image.tmdb.org/t/p/w1280';
  static const String imageBase_original = 'https://image.tmdb.org/t/p/original';
  static const String nowPlayingMovies = '$tmdbBase/movie/now_playing';
  static const String onTheAirTvShows = '$tmdbBase/tv/on_the_air';
  static const String trendingMovies = '$tmdbBase/trending/movie/week';
  static const String popularMovies = '$tmdbBase/movie/popular';
  static const String popularTvShows = '$tmdbBase/tv/popular';
  static const String topRatedMovies = '$tmdbBase/movie/top_rated';
  static const String topRatedTvShows = '$tmdbBase/tv/top_rated';
  static const String movieGenres = '$tmdbBase/genre/movie/list';
  static const String tvShowGenres = '$tmdbBase/genre/tv/list';
  static const String discoverMovie = '$tmdbBase/discover/movie';
  static const String discoverTvShow = '$tmdbBase/discover/tv';

  static const String subdlBase = 'https://api.subdl.com';
  static const String subdlDownloadBase = 'https://dl.subdl.com';
  static const String subtitles = '$subdlBase/api/v1/subtitles';

  static const String github = 'https://github.com/moses-mbaga/index';
  static const String mosesGithub = 'https://github.com/moses-mbaga';

  static String getMovieDetails(int id) => '$tmdbBase/movie/$id';
  static String getTvShowDetails(int id) => '$tmdbBase/tv/$id';
  static String getEpisodes(int id, int season) => '$tmdbBase/tv/$id/season/$season';
  static String getMovieVideosUrl(int id) => '$tmdbBase/movie/$id/videos';
  static String getTvShowVideosUrl(int id) => '$tmdbBase/tv/$id/videos';
  static String getMovieStreamUrl(int id) => 'https://vidsrc.cc/v2/embed/movie/$id';
  static String getEpisodeStreamUrl(int id, int season, int episode) => 'https://vidsrc.cc/v2/embed/tv/$id/$season/$episode';
  static String getMovieCast(int id) => '$tmdbBase/movie/$id/credits';
  static String getTvShowCast(int id) => '$tmdbBase/tv/$id/aggregate_credits';
  static String getPersonMovies(int id) => '$tmdbBase/person/$id/movie_credits';
  static String getPersonTvShows(int id) => '$tmdbBase/person/$id/tv_credits';
  static String getMovieRecommendations(int id) => '$tmdbBase/movie/$id/recommendations';
  static String getTvShowRecommendations(int id) => '$tmdbBase/tv/$id/recommendations';
  static String getMovieSimilar(int id) => '$tmdbBase/movie/$id/similar';
  static String getTvShowSimilar(int id) => '$tmdbBase/tv/$id/similar';

  static String getBestImageUrl(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth <= 45) {
      return imageBase_w45;
    } else if (screenWidth <= 92) {
      return imageBase_w92;
    } else if (screenWidth <= 154) {
      return imageBase_w154;
    } else if (screenWidth <= 185) {
      return imageBase_w185;
    } else if (screenWidth <= 300) {
      return imageBase_w300;
    } else if (screenWidth <= 342) {
      return imageBase_w342;
    } else if (screenWidth <= 500) {
      return imageBase_w500;
    } else if (screenWidth <= 632) {
      return imageBase_w632;
    } else if (screenWidth <= 780) {
      return imageBase_w780;
    } else if (screenWidth <= 1280) {
      return imageBase_w1280;
    } else {
      return imageBase_original;
    }
  }
}