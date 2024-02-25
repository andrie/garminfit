library(FITfileR)
library(dplyr)
library(RDP)

read_garmin <- function(file, record = 2) {
  record = paste("record", record, sep = "_")
  # browser()
  raw <- readFitFile(file)
  raw %>%
    records() %>%
    .[[record]] %>%
    mutate(
      timestamp = timestamp - timestamp[1],
      time = hms::as_hms(timestamp)
    ) %>%
    filter(time >= hms(seconds = 0)) %>%
    mutate(
      speed = c(0, diff(distance) / as.numeric(diff(timestamp))) * 3.6,
    ) %>%
    rename(
      lat = "position_lat",
      lon = "position_long"
    ) %>%
    select(
      timestamp, time, speed, everything()
    )
}


spatial_hash <- function(dat, round = 3) {
  dat %>%
  mutate(
    lonr = round(lon, {{ round }}),
    latr = round(lat, {{ round }}),
    new_rect = latr != lag(latr) | lonr != lag(lonr),
    new_rect = if_else(is.na(new_rect), TRUE, new_rect),
    new_rect = cumsum(new_rect)
  ) %>%
  group_by(new_rect) %>%
  summarise(
    lat = mean(lat),
    lon = mean(lon),
    speed = mean(speed),
    distance = max(distance),
    timestamp = max(timestamp),
    obs = n()
  ) %>%
    mutate(
      slice_distance = distance - lag(distance, default = 0)
    ) %>%
    rename(slice = "new_rect") %>%
    identity()
}

curvature <- function(lng, lat) {
  first_diff <- function(x) {
    tail(x, -2) - head(x, -2)
  }
  second_diff <- function(x) {
    tail(x,-2) - 2 * head(tail(x,-1),-1) + head(x,-2)
  }
  x <- lng
  y <- lat
  x1 <- first_diff(x)
  y1 <- first_diff(y)
  x2 <- second_diff(x)
  y2 <- second_diff(y)
  z <- abs(x1 * y2 - y1 * x2) / sqrt((x1^2 + y1^2)^3)
  c(0, z, 0)
}

simplify_track <- function(dat, epsilon = 0.0001, x = "lon", y = "lat") {
  RDP::RamerDouglasPeucker(dat[[x]], dat[[y]], epsilon = epsilon) %>%
  rename(lon = "x", lat = "y")
}
