# if(!requireNamespace("remotes")) install.packages("remotes")
# if(!requireNamespace("FITfileR")) remotes::install_github("grimbough/FITfileR")

library(FITfileR)
library(dplyr)
library(tibble)
library(ggplot2)
library(hms)
library(crayon)
library(mapproj)

raw <- readFitFile("data/paddle_hcc.fit")

# -------------------------------------------------------------------------


dat <-
  raw %>%
  records() %>%
  .$record_2 %>%
  mutate(
    timestamp = as.POSIXct(timestamp),
    timestamp = timestamp - timestamp[1],
    time = hms::as_hms(timestamp)
  ) %>%
  filter(time >= hms(seconds = 0)) %>%
  mutate(
    time = time - hms(seconds = 0),
    time = as_hms(time),
    # speed = enhanced_speed * 3.6,
    speed = c(0, diff(distance) / as.numeric(diff(timestamp))) * 3.6,
    segment = case_when(
      distance < 50 ~ "0 start",
      distance > 50 & distance < 1950 ~ "1 upstream",
      distance >= 1950 & distance < 2300 ~ "2 island",
      distance >=2300 & distance < 4690 ~ "3 downstream",
      distance > 4690 ~ "4 finish"
    )
  )

dat
# dat %>% view()

dat %>%
  group_by(segment) %>%
  summarise(
    m = sum(speed * distance) / sum(distance),
    m2 = mean(speed)
  ) %>%
  mutate(
    pace = as_hms(1/m2 * 60)
  )

dat %>% summarise(mean(speed))


dat %>%
  ggplot(aes(x = time, y = speed)) +
  geom_line() +
  geom_point(aes(colour = segment), size = 1) +
  geom_smooth(method = "lm", aes(colour = segment)) +
  ylab("speed (km/h)") +
  coord_cartesian(ylim = c(0, 12))

dat %>%
  # geom_line() +
  ggplot(aes(x = position_long, y = position_lat, colour = speed)) +
  geom_path() +
  geom_point() +
  coord_map()
