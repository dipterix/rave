#' Async way to lapply with no block
#' @param X, x
#' @param FUN see lapply
#' @param ... see lapply
#' @param .get_values return future objects or future values
rave_lapply <- function(X, FUN, ..., .get_values = TRUE){
  lapply(X, function(x){
    async({
      FUN(x, ...)
    })
  }) ->
    futures

  if(.get_values){
    futures = get_results(futures)
  }
  return(futures)
}

#' Get future objects result
#' @param futures list of future objects
get_results <- function(futures){
  lapply(futures, future::value)
}
