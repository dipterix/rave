#' @import stringr
parse_selections <- function(text, sep = ',', sort = F, unique = T){
  if(length(text) == 0 || str_trim(text) == ''){
    return(NULL)
  }

  if(is.numeric(text)){
    return(text)
  }
  s = as.vector(str_split(text, sep, simplify = T))
  s = str_trim(s)
  s = s[s!='']

  s = s[str_detect(s, '^[0-9\\-\\ ]+$')]

  re = NULL
  for(ss in s){
    if(str_detect(ss, '\\-')){
      ss = as.vector(str_split(ss, '\\-', simplify = T))
      ss = ss[str_detect(ss, '^[0-9]+$')]
      ss = as.numeric(ss)
      if(length(ss) >= 2){
        re = c(re, (ss[1]:ss[2]))
      }
    }else{
      re = c(re, as.numeric(ss))
    }
  }

  if(unique){
    re = unique(re)
  }

  if(sort){
    re = sort(re)
  }

  return(re)
}


#' @import stringr
deparse_selections <- function(nums, link = '-', concatenate = T){
  if(length(nums) == 0){
    return('')
  }
  nums = sort(unique(nums))
  lg = c(NA, nums)[1:length(nums)]
  ind = nums - lg; ind[1] = 0
  ind2 = c(ind[-1], -1)

  apply(cbind(nums[ind != 1], nums[ind2 != 1]), 1,function(x){
    if(x[1] == x[2]){
      str_c(x[1])
    }else{
      str_c(x, collapse = link)
    }
  }) ->
    re
  if(concatenate){
    re = str_c(re, collapse = ',')
  }
  re
}