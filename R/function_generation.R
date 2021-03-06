




test_string_to_report <- function(
  test_string,
  pass_message = NA_character_,
  fail_message = NA_character_,
  env = parent.frame(1L)
  ) {
  test_expr <- parse(text = test_string)[[1L]]

  eval_env <- new.env(parent = env)
  result <- tryCatch(
    eval(test_expr, envir = eval_env),
    error = function(e) e
  )
  pass <- FALSE
  error <- NA_character_
  n_fail <- NA_integer_
  wh_fail <- NA_integer_
  if (inherits(result, "error")) {
    error <- result[["message"]]
  } else if (is.null(result)) {
    pass <- TRUE
  } else if (is.logical(result)) {
    pass <- all(result %in% TRUE)
    if (length(result) != 1L) {
      n_fail <- sum(!result, na.rm = TRUE)
      wh_fail <- which(!result)
    }
  } else {
    stop("test ", deparse(test_string), " returned result of class(es) ",
         deparse(class(result)), "; logical or NULL was expected; see ",
         "help for argument 'tests'")
  }
  df <- data.frame(
    test = test_string,
    error = error,
    pass = pass,
    n_fail = n_fail
  )
  df[["wh_fail"]] <- list(wh_fail)
  df_env <- as.environment(df)
  df_env[["wh_fail"]] <- df[["wh_fail"]][[1L]]
  parent.env(df_env) <- parent.env(eval_env)
  parent.env(eval_env) <- df_env
  if (df[["pass"]]) {
    df[["message"]] <- interpolate(pass_message, env = eval_env)
  } else {
    msg <- interpolate(fail_message, env = eval_env)
    df[["message"]] <- msg
  }
  df[]
}





#' @title Tests to Reports to Assertions
#' @description
#' Collect tests into a report data.frame, raise assertion errors in failed
#' tests in report.
#' @name tests_to_reports_to_assertions
NULL

#' @rdname tests_to_reports_to_assertions
#' @export
#' @param tests `[character, list]` (mandatory, no default)
#'
#' - `character`: vector of tests to perform; after parsing each string
#'   the evaluated expression must return a logical vector or `NULL`,
#'   where `NULL` is interpreted as pass
#' - `list`: each element is either a character string as above or a language
#'   object (see e.g. [quote]) which is deparsed into a string
#' @param fail_messages `[NULL, character]` (optional, default `NULL`)
#'
#' - `NULL`: use `"at least one FALSE value in test: ${test}"`
#' - `character`: use these messages (one for each test); `NA_character_`
#'   values are replaced with the same message as when this argument is
#'   `NULL`
#'
#' messages (one for each test) to include in report upon failure; see section
#' **Interpolation in messages**
#' @param pass_messages `[NULL, character]` (optional, default `NULL`)
#'
#' - `NULL`: use `"all were TRUE in test: ${test}"`
#' - `character`: use these messages (one for each test); `NA_character_`
#'   values are replaced with the same message as when this argument is
#'   `NULL`
#'
#' as `fail_messages` but for tests successes
#' @param env `[environment]` (optional, default `parent.frame(1L)`)
#'
#' a new environment is created for evaluating each test given in `tests`;
#' this environment will be the parent environment of each of the temporary
#' environments; the default is the parent environment of the function execution
#' environment

#' @param call `[language, NULL]` (optional, default `NULL`)
#'
#' - `language`: an R language object such as one produced by [match.call] or
#'   `quote`; this call will be reported in an error
#' - `NULL`: the call is attempted to be inferred
#'
#' @section Interpolation in messages:
#' `fail_messages` and `pass_messages` can use variables you create in a test
#' and information created based on the result of the test. For an individual
#' message, you may include any of the variables listed in **Value** for that
#' test except the message itself by using the syntax `${object}` in your
#' test string; e.g. `"this many failed: ${n_fail}"`. You may include any
#' variables you created in the test, using the same logic, e.g. with test
#' `"(len <- length(x)) == 1L"` you may do `"expected length 1, got ${len}"`.
#' Finding variables to interpolate into the string is searched for in the
#' set of variables created in your test first and then in the variables
#' derived from the result of the test. You may also interpolate any
#' transformations of the available variables: e.g.
#' `"${round(100 * n_fail / length(x))} % were invalid"`
#'
#' @return
#' For `tests_to_report`, a `data.frame` with columns
#'
#' - `test`: argument `tests` as-is
#' - `error`: the error message if the test resulted in an error; `NA` if it
#'   did not
#' - `pass`: `TRUE` if corresponding test evaluated to logical and all were
#'   `TRUE`, otherwise `FALSE` (i.e. any `NA` values leads to `FALSE`)
#' - `n_fail`: number of elements of result of test that were `FALSE` or `NA`;
#'   if result was not a logical vector of length greater than one, this is `NA`
#' - `wh_fail`: integer vector of positions of test result that were `FALSE`
#'   or `NA`; if result was not a logical vector of length greater than one,
#'   this is `NA`
#' - `message`: the corresponding `fail_messages` or `pass_messages`
#'   element (after interpolation) depending on `pass`
#'
#' @examples
#' # tests_to_report
#'
#' a <- 1:5
#' b <- 1:5
#' # pass
#' tests_to_report(
#'   tests = "a == b"
#' )
#' # fail
#' tests_to_report(
#'   tests = "a == (b + 1)"
#' )
#' # error
#' tests_to_report(
#'   tests = "a == d"
#' )
tests_to_report <- function(
  tests,
  fail_messages = NULL,
  pass_messages = NULL,
  env = parent.frame(1L),
  call = NULL
) {

  call <- infer_call(call = call, env = env)
  if (is.null(call)) {
    call <- match.call()
  }

  raise_internal_error_if_not(
    inherits(tests, c("list", "character"))
  )
  if (inherits(tests, "list")) {
    raise_internal_error_if_not(
      vapply(tests, is.language, logical(1L)) | vapply(
        tests, is.character, logical(1L)
      )
    )
    tests <- vapply(tests, function(elem) {
      if (!is.character(elem)) {
        elem <- paste0(deparse(elem), collapse = "")
      }
      elem
    }, character(1L))
  }
  call <- infer_call(call = call, env = env)

  stopifnot(
    is.null(fail_messages) || (
      is.character(fail_messages) &&
        length(fail_messages) %in% c(1L, length(tests))
    ),

    is.null(pass_messages) || (
      is.character(pass_messages) &&
        length(pass_messages) %in% c(1L, length(tests))
    ),

    is.environment(env)
  )

  if (is.null(fail_messages)) {
    fail_messages <- "at least one FALSE value in test: ${test}"
  }
  if (length(fail_messages) == 1L) {
    fail_messages <- rep(fail_messages, length(tests))
  }
  fail_messages[is.na(fail_messages)] <- paste0(
    "test failed: ", tests[is.na(fail_messages)]
  )
  if (is.null(pass_messages)) {
    pass_messages <- "all were TRUE in test: ${test}"
  }
  if (length(pass_messages) == 1L) {
    pass_messages <- rep(pass_messages, length(tests))
  }
  pass_messages[is.na(pass_messages)] <- paste0(
    "test passed: ", tests[is.na(pass_messages)]
  )

  test_df_list <- lapply(seq_along(tests), function(test_pos) {

    test_string_to_report(
      test_string = tests[test_pos],
      pass_message = pass_messages[test_pos],
      fail_message = fail_messages[test_pos],
      env = env
    )

  })

  report_df <- do.call(rbind, test_df_list)
  report_df[, names(report_df)] <- lapply(report_df, function(col) {
    if (is.factor(col)) {
      col <- as.character(col)
    }
    col
  })

  report_df[["call"]] <- lapply(1:nrow(report_df), function(i) call)

  return(report_df)
}


assertion_types <- function() {
  c("general", "user_input", "prod_input", "dev_input",
    "prod_output", "dev_output",
    "prod_interim", "dev_interim")
}
dev_assertion_types <- function() {
  at <- assertion_types()
  at[grepl("^dev_", at)]
}



#' @rdname tests_to_reports_to_assertions
#' @export
#' @param report_df `[data.frame]` (mandatory, no default)
#'
#' a report `data.frame` as returned by `tests_to_report`
#' @param assertion_type `[character]` (mandatory, default `"general"`)
#'
#' the type of assertion alters the emitted error message to e.g. direct the
#' end-user to adjust their arguments supplied to a function or to report
#' and internal error; the error messages are altered by type as follows:
#'
#' - `"general"`: just says that assertions did not pass without information
#'   as to whose fault this was
#' - `"user_input"`: the end-user is directed to adjust their arguments.
#' - `"prod_input"`: the assertion error is considered to be an internal error,
#'   and the end-user is directed to report it; the inputs of some function
#'   were not as expected
#' - `"dev_input"`: only the developer is notified (see \link{dbc}[dbc])
#' - `"prod_output"`: like `"prod_input"`, but the output of some function
#'   was not as expected
#' - `"dev_output"`: like `"prod_output"`, but only raised in development mode
#'   (see \link{dbc}[dbc])
#' - `"prod_interim"`: like `"prod_input"`, but the interim result somewhere
#'   was not as expected
#' - `"dev_interim"`: like `"prod_interim"`, but only raised in development mode
#'   (see \link{dbc}[dbc])
#'
#' @param raise_error_call `[NULL, language]` (optional, default `NULL`)
#'
#' the call to display in the error call; passed to arg `call` of
#' [base::simpleError].
#'
#' - `NULL`: use the parent call; when this function is called in another
#'   function (as it is intended to be used), the function call of the
#'   surrounding function is used; see **Examples**
#' - `language`: this call is used as-is.
#'
#'
#' @examples
#' # report to assertion
#'
#' # pass
#' report_df <- tests_to_report("1 == 1")
#' report_to_assertion(report_df)
#'
#' # fail
#' report_df <- tests_to_report("1 == 2")
#' tryCatch(
#'   report_to_assertion(report_df),
#'   error = function(e) e
#' )
#'
#' # 2 passes, 2 failures
#' report_df <- tests_to_report(c("1 == 2", "1 == 1", "2 == 2", "2 == 1"))
#' tryCatch(
#'   report_to_assertion(report_df),
#'   error = function(e) e
#' )
#'
#' my_fun <- function(my_arg) {
#'   report_to_assertion(tests_to_report("is.character(my_arg)"))
#' }
#' tryCatch(
#'   my_fun(my_arg = 1L),
#'   error = function(e) e
#' )
report_to_assertion <- function(
  report_df,
  assertion_type = "general",
  raise_error_call = NULL
) {
  raise_internal_error_if_not(
    is.data.frame(report_df),
    c("pass", "message", "error", "call") %in% names(report_df),

    length(assertion_type) == 1L,
    assertion_type %in% assertion_types(),

    is.null(raise_error_call) || is.language(raise_error_call)
  )
  if (is.null(raise_error_call)) {
    raise_error_call <- tryCatch(
      eval(quote(match.call()), parent.frame(1L)),
      error = function(e) e
    )
    if (inherits(raise_error_call, c("error", "try-error"))) {
      raise_error_call <- match.call()
    }
  }

  if (assertion_type %in% dev_assertion_types() && get_dev_mode() == FALSE) {
    return(invisible(NULL))
  }
  report_df[, names(report_df)] <- lapply(report_df, function(col) {
    if (is.factor(col)) {
      col <- as.character(col)
    }
    col
  })
  wh_nonpass <- which(!report_df[["pass"]] %in% TRUE)
  if (length(wh_nonpass) > 0L) {
    msgs <- vapply(
      wh_nonpass,
      function(test_no) {
        suffix <- paste0("failed: ", report_df[["message"]][test_no])
        error_msg <- report_df[["error"]][test_no]
        if (!is.na(error_msg)) {
          suffix <- paste0("encountered an ERROR: ", error_msg)
        }
        test_string <- paste0(deparse(
          report_df[["test"]][test_no]
        ), collapse = "")
        paste0("test ", test_string, " ", suffix)
      },
      character(1L)
    )
    call_strings <- vapply(wh_nonpass, function(test_no) {
      call <- report_df[["call"]][[test_no]]
      if (is.null(call)) {
        call_string <- "in unknown call, "
      } else {
        call_string <- paste0(
          "in call ", paste0(deparse(call), collapse = ""), ", "
        )
      }
      gsub("\\s+", " ", call_string)
    }, character(1L))
    msgs <- paste0(call_strings, msgs)

    msg_start <- switch(
      assertion_type,
      general = "assertion failure(s):",
      user_input = paste0(
        "Hi user! One or more arguments you supplied did not comply with ",
        "their specifications; please see the points below and adjust ",
        "your arguments."
      ),
      prod_input = paste0(
        "Internal error: one or more arguments supplied to an internally used ",
        "function did not comply with specfications; please report this error ",
        "to the author or maintainer of the command you used. These were ",
        "the errors:"
      ),
      dev_input = paste0(
        "Internal error: one or more arguments supplied to an internally used ",
        "function did not comply with specfications tested in development ",
        "mode; these were the errors:"
      ),
      prod_output = paste0(
        "Internal error: the output of an internally used function did not ",
        "comply with specifications; please report this error ",
        "to the author or maintainer of the command you used. These were ",
        "the errors:"
      ),
      dev_output = paste0(
        "Internal error: the output of an internally used function did not ",
        "comply with specifications tested in development mode; These were ",
        "the errors:"
      ),
      prod_interim = paste0(
        "Internal error: an interim results of inside a function was not as ",
        "expected; please report this error ",
        "to the author or maintainer of the command you used. These were ",
        "the errors:"
      ),
      dev_interim = paste0(
        "Internal error: an interim results of inside a function was not as ",
        "expected when in development mode; These were the errors:"
      )
    )
    msg <- paste0(
      c(msg_start, paste0(" - ", msgs)),
      collapse = "\n"
    )
    stop(simpleError(msg, raise_error_call))
  }

  return(invisible(NULL))
}



interpolate <- function(x, env = parent.frame(1L)) {
  stopifnot(
    is.character(x),
    is.environment(env)
  )
  m <- gregexpr(pattern = "\\Q${\\E[^{]+\\Q}\\E", text = x, perl = TRUE)
  expr_strings_by_x_elem <- regmatches(x = x, m = m)
  has_nothing_to_interpolate <- length(expr_strings_by_x_elem) == 1L &&
    length(expr_strings_by_x_elem[[1L]]) == 0L
  if (has_nothing_to_interpolate) {
    return(x)
  }

  values <- lapply(expr_strings_by_x_elem, function(expr_string_vec) {
    expr_string_vec <- substr(expr_string_vec, 3L, nchar(expr_string_vec) - 1L)
    vapply(expr_string_vec, function(string) {
      expr <- parse(text = string)[[1L]]
      expr_nms <- all.names(expr, unique = TRUE)
      expr_object_exists <- vapply(expr_nms, function(obj_nm) {
        !isFALSE(tryCatch(expr = get(obj_nm, envir = env),
                          warning = function(w) FALSE,
                          error = function(e) FALSE))
      }, logical(1L))
      if (!all(expr_object_exists)) {
        evaled <- string
      } else {
        evaled <- tryCatch(
          eval(expr, envir = env),
          error = function(e) e
        )
        if (inherits(evaled, c("error", "try-error"))) {
          evaled <- string
        }
      }
      paste0(as.character(evaled), collapse = "")
    }, character(1L))
  })
  regmatches(x = x, m = m) <- values
  x
}



get_report_fun_specs <- function() {
  report_fun_specs
}



#' @importFrom stats aggregate
generate_base_report_funs <- function(
  target_script = "R/generated_base_report_funs.R"
) {
  specs_df <- get_report_fun_specs()
  raise_internal_error_if_not(
    is.data.frame(specs_df),
    c("test_set_nm", "call",
      "fail_message", "pass_message", "extra_arg_nm_set") %in% names(specs_df),

    is.character(target_script),
    length(target_script) == 1L
  )
  specs_df[, names(specs_df)] <- lapply(specs_df, as.character)
  base_prefix <- "report_"
  fun_df <- data.frame(suffix = sort(unique(specs_df[["test_set_nm"]])))
  fun_df[["suffix"]] <- as.character(fun_df[["suffix"]])
  fun_df[["nm"]] <- paste0(base_prefix, fun_df[["suffix"]])

  test_set_nm_set <- fun_df$suffix
  fun_df[["extra_arg_set"]] <- lapply(test_set_nm_set, function(test_set_nm) {
    is_test_set <- specs_df[["test_set_nm"]] == test_set_nm
    values <- specs_df[["extra_arg_nm_set"]][is_test_set]
    paste0(setdiff(values, c(NA_character_, "")), collapse = ", ")
  })
  split_col_nms <- c("test_set" = "call", "fail_msg_set" = "fail_message", "pass_msg_set" = "pass_message")
  fun_df[, names(split_col_nms)] <- lapply(split_col_nms, function(col_nm) {
    src_col_nm <- col_nm
    lapply(test_set_nm_set, function(test_set_nm) {
      is_test_set <- specs_df[["test_set_nm"]] == test_set_nm
      values <- specs_df[[src_col_nm]][is_test_set]
      paste0(deparse(values), collapse = "")
    })
  })
  fun_df[["body"]] <- lapply(1:nrow(fun_df), function(fun_no) {
    body <- paste0("  ", c(
      "x_nm <- handle_x_nm_arg(x_nm)",
      "call <- infer_call(call = call, env = parent.frame(1L))",
      "report_env <- environment()",
      "test_set <- c(",
      paste0("  ", fun_df[["test_set"]][fun_no]),
      ")",
      "fail_msg_set <- c(",
      paste0("  ", fun_df[["fail_msg_set"]][fun_no]),
      ")",
      "pass_msg_set <- c(",
      paste0("  ", fun_df[["pass_msg_set"]][fun_no]),
      ")",
      "report_df <- tests_to_report(",
      "  tests = test_set,",
      "  fail_messages = fail_msg_set,",
      "  pass_messages = pass_msg_set,",
      "  env = report_env, ",
      "  call = call",
      ")",
      "return(report_df)"
    ))
    body
  })
  fun_df[["fun_def"]] <- lapply(1:nrow(fun_df), function(fun_no) {
    body <- fun_df[["body"]][[fun_no]]
    arg_set <- c("x", "x_nm = NULL", "call = NULL")
    arg_set <- setdiff(
      c(arg_set, fun_df[["extra_arg_set"]][fun_no]),
      c(NA_character_, "")
    )
    arg_set <- paste0(arg_set, collapse = ", ")
    def <- c(
      "#' @rdname assertions",
      "#' @export",
      paste0(fun_df[["nm"]][fun_no], " <- function(", arg_set, ") {"),
      body,
      "}"
    )
  })

  lines <- c(
    "# this script was generated automatically. do not edit by hand!",
    rep("", 5),
    unlist(lapply(fun_df[["fun_def"]], function(x) {
      c(
        "# this function was generated automatically. do not edit by hand!",
        x,
        rep("", 3)
      )
    }))
  )

  writeLines(text = lines, con = target_script)
}


generate_report_derivative_funs <- function(
  source_scripts = c(
    "R/generated_base_report_funs.R",
    "R/generated_report_fun_variants.R"
  ),
  target_script = "R/generated_assertion_funs.R",
  type = c("assert", "test")[1],
  assertion_type = "general"
) {
  stopifnot(
    type %in% c("assert", "test"),
    length(type) == 1L,

    length(assertion_type) == 1L, is.character(assertion_type)
  )
  fun_env <- new.env()
  invisible(lapply(source_scripts, function(script_path) {
    source(script_path, local = fun_env)
  }))

  obj_nms <- ls(envir = fun_env)
  is_report_fun_nm <- grepl(
    pattern = "^report_[_.a-zA-Z0-9]+",
    x = obj_nms
  )
  report_fun_nms <- gsub("\\Q <- \\E.+", "", obj_nms[is_report_fun_nm])
  if (type == "assert" && assertion_type != "general") {
    fun_nms <- sub(
      "^report_", paste0(type, "_", assertion_type, "_"), report_fun_nms
    )
  } else {
    fun_nms <- sub(
      "^report_", paste0(type, "_"), report_fun_nms
    )
  }

  fun_df <- data.frame(fun_nm = fun_nms, report_fun_nm = report_fun_nms)

  body_part <- switch(
    type,
    assert = c(
      paste0(
        "report_to_assertion(report_df, assertion_type = \"",
        assertion_type,
        "\")"
      ),
      "return(invisible(NULL))"
    ),
    test = c(
      "return(all(report_df[[\"pass\"]]))"
    )
  )


  fun_df[["body"]] <- lapply(1:nrow(fun_df), function(fun_no) {
    report_fun_nm <- report_fun_nms[fun_no]
    arg_nms <- names(formals(fun_env[[report_fun_nm]]))
    paste0("  ", c(
      "x_nm <- handle_x_nm_arg(x_nm)",
      "call <- infer_call(call = call, env = parent.frame(1L))",
      "if (is.null(call)) {",
      "  call <- match.call()",
      "}",
      paste0("report_df <- ", fun_df[["report_fun_nm"]][fun_no], "("),
      paste0(
        "  ", arg_nms, " = ", arg_nms, c(rep(", ", length(arg_nms) - 1L), "")
      ),
      ")",
      body_part
    ))
  })

  fun_df[["arg_set"]] <- lapply(report_fun_nms, function(report_fun_nm) {
    formals <- formals(fun_env[[report_fun_nm]])
    arg_set <- vapply(
      seq_along(formals),
      function(formal_no) {
        formal_nm <- names(formals)[formal_no]
        formal_default <- paste0(deparse(formals[[formal_no]]), collapse = "")
        ifelse(formal_default %in% c("", NA_character_), formal_nm,
               paste0(formal_nm, " = ", formal_default))
      },
      character(1L)
    )
    arg_set
  })

  fun_df[["def"]] <- lapply(1:nrow(fun_df), function(fun_no) {
    fun_nm <- fun_df[["fun_nm"]][fun_no]
    body <- fun_df[["body"]][[fun_no]]
    arg_set <- fun_df[["arg_set"]][[fun_no]]
    def <- c(
      paste0(fun_nm, " <- function("),
      paste0("  ", arg_set, c(rep(", ", length(arg_set) - 1L), "")),
      ") {",
      body,
      "}"
    )
    def
  })

  lines <- unlist(lapply(fun_df[["def"]], function(lines) {
    c(
      rep("", 5),
      "# this function was generated automatically. do not edit by hand!",
      "#' @rdname assertions",
      "#' @export",
      lines
    )
  }))

  lines <- c(
    "# this script was generated automatically. do not edit by hand!",
    lines, rep("", 5)
  )

  writeLines(lines, con = target_script)

}

generate_test_funs <- function(
  source_scripts = c(
    "R/generated_base_report_funs.R",
    "R/generated_report_fun_variants.R"
  ),
  target_script = "R/generated_assertion_funs.R"
) {
  generate_report_derivative_funs(
    source_scripts = source_scripts,
    target_script = target_script,
    type = "test"
  )
}

generate_assertion_funs <- function(
  source_scripts = c(
    "R/generated_base_report_funs.R",
    "R/generated_report_fun_variants.R"
  ),
  target_script = "R/generated_test_funs.R",
  assertion_type = "general"
) {
  generate_report_derivative_funs(
    source_scripts = source_scripts,
    target_script = target_script,
    type = "assert",
    assertion_type = assertion_type
  )
}

generate_function_variants <- function(
  prefix = c("report", "assert", "test")[1],
  target_script = "R/generated_report_fun_variants.R",
  pad = rep("", 5)
) {
  requireNamespace("data.table")
  levels <- list(
    c("double", "number", "integer", "Date", "character", "logical",  "factor"),
    "_",
    c("nonNA", ""),
    "_",
    c("gtezero", "gtzero", "ltezero", "ltzero", ""),
    "_",
    c("atom", "vector", "matrix")
  )

  fun_def_prefix <- paste0(prefix, "_is_")

  fun_nm_dt <- do.call(data.table::CJ, levels)
  data.table::setkeyv(fun_nm_dt, names(fun_nm_dt))
  non_number_types <- c("character", "logical", "Date", "factor")
  fun_nm_dt <- fun_nm_dt[
    !(fun_nm_dt[["V1"]] %in% non_number_types &
        fun_nm_dt[["V5"]] != ""),
  ]
  fun_nms <- do.call(paste0, fun_nm_dt)
  fun_nms <- paste0(fun_def_prefix, fun_nms)
  fun_nms <- gsub("_{1,}", "_", fun_nms)

  data.table::set(fun_nm_dt, j = c("V2", "V4", "V6"), value = NULL)
  data.table::set(
    fun_nm_dt,
    j = names(fun_nm_dt),
    value = lapply(fun_nm_dt, function(col) {
      fun_nms <- paste0(fun_def_prefix, col)
      fun_calls <- paste0(fun_nms, "(x = x, x_nm = x_nm, call = call)")
      fun_calls[col == ""] <- ""
      fun_calls
    })
  )

  fun_definitions <- unlist(lapply(seq_along(fun_nms), function(i) {
    fun_nm <- fun_nms[i]
    def <- paste0(fun_nm, " <- function(x, x_nm = NULL, call = NULL) {")
    call_lines <- setdiff(as.character(fun_nm_dt[i, ]), "")
    line_ends <- c(rep(", ", length(call_lines) - 1L), "")
    def <- c(
      def,
      "  x_nm <- handle_x_nm_arg(x_nm)",
      "  call <- infer_call(call = call, env = parent.frame(1L))",
      "  out <- rbind(",
      paste0("    ", call_lines, line_ends),
      "  )",
      "  return(out)"
    )
    def <- c(def, "}", rep("", 1))
    def <- c(
      "#' @rdname assertions",
      "#' @export",
      def
    )
  }))

  lines <- c(pad, fun_definitions)

  writeLines(text = lines, con = target_script)
  invisible(NULL)
}




