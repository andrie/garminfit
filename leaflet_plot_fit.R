
library(dplyr)
library(tibble)
library(ggplot2)
library(hms)
library(crayon)
library(mapproj)
library(RcppRoll)
library(tidyr)

source("R/garmin.R")
data_file <- "data/paddle_walton.fit"
data_file <- "data/paddle_hcc.fit"
data_file <- "data/paddle_intervals.fit"
dat <- read_garmin(data_file)
dat


# RDP simplification and curvature ----------------------------------------

# https://stackoverflow.com/questions/14631776/calculate-turning-points-pivot-points-in-trajectory-path

dist <- function(x, y) {
  # if (is.na(x0) | is.na(y0)) return(NA)
  x0 <-  head(x, -1)
  x1 <- tail(x, -1)
  y0 <-  head(y, -1)
  y1 <- tail(y, -1)
  c(0, sqrt((y1 - y0)^2 + (x1 - x0)^2))
}

dat %>%
  simplify_track(epsilon = 0.00005) %>%
  mutate(
    curvature = (1 + curvature(lon, lat)) %>% log10,
    # tp = if_else(curvature >= 2, curvature, 0),
    tp = curvature,
    id = 1:n()
    # lag = lag(lon)
    # distance = lag(lon) - lon
  ) %>%
  filter(tp >= 2) %>%
  mutate(
    distance = dist(lon, lat)
  )

dat %>%
  simplify_track(epsilon = 0.00005) %>%
  mutate(
    curvature = (1 + curvature(lon, lat)) %>% log10,
    tp = if_else(curvature >= 2, curvature, 0)
    ) %>%
  ggplot(aes(x = lon, y = lat)) +
  geom_path() +
  geom_point(aes(size = tp, colour = tp)) +
  labs(colour = "curve", size = "curve") +
  coord_map()

# - -----------------------------------------------------------------------



dat
dat %>%
  spatial_hash() %>%
  tail()


# - -----------------------------------------------------------------------



dat %>%
  spatial_hash() %>%
  ggplot(aes(x = lon, y = lat, colour = speed)) +
  geom_path(linewidth = 1) +
  geom_point() +
  scale_colour_gradient2(midpoint = 8, low = "black", mid = "blue", high = "red") +
  coord_map()

# plot polylines in multiple colours -------------------------------------

pal_rb <- scales::gradient_n_pal(c("red", "blue"))

mdat <-
  dat %>%
  spatial_hash() %>%
  mutate(
    speed_01 = scales::rescale(speed),
    colour = pal_rb(round(speed_01, 1))
  )

library(leaflet)

m <-
  mdat %>%
  leaflet() %>%
  addTiles()
for (g in 2:nrow(mdat) ) {
  m <-
    m %>%
    addPolylines(lng = ~lon, lat = ~lat, color = ~colour, data = mdat[(g-1):g, ])
}
m

# compute curvature -------------------------------------------------------

dat
with(dat %>% spatial_hash(), curvature(lon, lat))

dat %>%
  spatial_hash(round = 3) %>%
  mutate(
    curvature = log1p(curvature(lon, lat)),
    curvature = if_else(curvature < 5, 0, curvature)
    ) %>%
  select(timestamp, speed, lat, lon, curvature) %>%
  ggplot(aes(x = lon, y = lat, colour = curvature)) +
  geom_path() +
  geom_point(aes(size = curvature)) +
  coord_map()
  # scale_size_continuous(trans = "log1p") +
  # scale_colour_continuous(trans = "log1p")





library(sf)
library(sfheaders)
library(leaflet)

dat %>%
  spatial_hash() %>%
  sfheaders::sf_linestring(x = "lon", y = "lat", keep = TRUE) %>%
  leaflet() %>%
  addTiles() %>%
  addPolylines()





