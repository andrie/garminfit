if(!requireNamespace("remotes")) install.packages("remotes")
if(!requireNamespace("FITfileR")) remotes::install_github("grimbough/FITfileR")

library(FITfileR)
library(dplyr)
library(tibble)
library(ggplot2)

raw <- readFitFile("data/paddle_intervals.fit")

# -------------------------------------------------------------------------


dat <-
  raw %>%
  records() %>%
  .$record_2 %>%
  mutate(
    timestamp = as.numeric(timestamp),
    timestamp = timestamp - timestamp[1]
  ) %>%
  filter(timestamp > 2750, timestamp < 5250) %>%
  mutate(
    speed = enhanced_speed * 3600 / 1000,
    # speed = c(0, diff(distance) / as.numeric(diff(timestamp))) * 3.6,
    s = timestamp - lag(timestamp),
    fast = enhanced_speed > 2.6,
    n = ifelse(fast != lag(fast, default = 0), 1, 0),
    n = cumsum(n),
    interval = if_else((n %% 2) == 0, 0, (n + 1) / 2 )
  ) %>%
  select(
    timestamp, speed, s, interval
  )
dat
# dat %>% view()

dat %>%
  group_by(interval) %>%
  summarise(
    m = mean(speed)
  )


dat %>%
  ggplot(aes(x = timestamp, y = speed)) +
  geom_point(aes(colour = factor(interval)), size = 1) +
  geom_line() +
  geom_smooth(data = dat %>% filter(interval > 0), method = "lm", aes(colour = factor(interval))) +
  ylab("speed (km/h)")
