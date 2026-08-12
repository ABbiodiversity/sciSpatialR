test_that("catalogue placeholder functions throw not-implemented error", {
  expect_error(list_layers(),  "not yet implemented")
  expect_error(find_layer(),   "not yet implemented")
  expect_error(get_layer("x"), "not yet implemented")
  expect_error(layer_meta("x"), "not yet implemented")
})

test_that("catalogue error message is not circular", {
  err <- tryCatch(list_layers(), error = function(e) conditionMessage(e))
  expect_false(grepl("list_layers\\(\\) once", err))
})

test_that("get_layer and layer_meta error on bad name argument", {
  expect_error(get_layer(123),    "`name` must be a single")
  expect_error(layer_meta(NULL),  "`name` must be a single")
})
