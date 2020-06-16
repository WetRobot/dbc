

source("data-raw/sysdata.R")

pkgload::load_all(export_all = TRUE)
generate_base_report_funs(
  target_script = "R/generated_base_report_funs.R"
)
generate_function_variants(
  prefix = "report",
  target_script = "R/generated_report_fun_variants.R"
)

generate_assertion_funs(
  source_scripts = c(
    "R/generated_base_report_funs.R",
    "R/generated_report_fun_variants.R"
  ),
  target_script = "R/generated_assertion_funs.R"
)

generate_test_funs(
  source_scripts = c(
    "R/generated_base_report_funs.R",
    "R/generated_report_fun_variants.R"
  ),
  target_script = "R/generated_test_funs.R"
)