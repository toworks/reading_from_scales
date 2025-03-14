package scales

import (
	"fmt"
	"regexp"
	"strings"
	"time"
)

const TimeFormatReverse string = "02.01.06 15:04:05"
const TimeFormatDirect string = "01.02.06 15:04:05"

func (c *Config) ProcessingBullat(message string) {
  msg := regexp.MustCompile("(?m).*<(.*);>[\\n\\r]+.*").ReplaceAllString(message, "$1")

  values := strings.Split(msg, ";")

  for i, v := range values {
	values[i] = strings.TrimSpace(v)
  }

  _id_scales := fmt.Sprintf("%d", c.Id_scale)
  _timestamp := c.get_datetime(values[0])
  _weight := values[1]
  _weight_platform_1 := values[5]
  _weight_platform_2 := values[9]
  _weightStabilized_1 := values[4]
  _weightStabilized_2 := values[4]

  if DEBUG.enable {
    c.ch_message <- fmt.Sprintf("d|:|%s: ProcessingBullat message: %#v", mod_name, msg)
	c.ch_message <- fmt.Sprintf("d|:|%s: ProcessingBullat values: %#v", mod_name, values)
	c.ch_message <- fmt.Sprintf("d|:|%s: ProcessingBullat  id_scale: %s  _timestamp: %s", mod_name, _id_scales, _timestamp)
	c.ch_message <- fmt.Sprintf("d|:|%s: ProcessingBullat  id_scale: %s  _weight: %s", mod_name, _id_scales, _weight)
	c.ch_message <- fmt.Sprintf("d|:|%s: ProcessingBullat  id_scale: %s  _weight_platform_1: %s", mod_name, _id_scales, _weight_platform_1)
	c.ch_message <- fmt.Sprintf("d|:|%s: ProcessingBullat  id_scale: %s  _weight_platform_2: %s", mod_name, _id_scales, _weight_platform_2)
	c.ch_message <- fmt.Sprintf("d|:|%s: ProcessingBullat  id_scale: %s  _weightStabilized_1: %s", mod_name, _id_scales, _weightStabilized_1)
	c.ch_message <- fmt.Sprintf("d|:|%s: ProcessingBullat  id_scale: %s  _weightStabilized_2: %s", mod_name, _id_scales, _weightStabilized_2)
  }
}

func (c *Config) get_datetime(timestamp string) string {
  dt, err := time.Parse(TimeFormatReverse, timestamp)
  if err != nil {
	c.ch_message <- fmt.Sprintf("e|:|%s: format: TimeFormatReverse  error: %s\n", mod_name, err.Error())
	dt, err = time.Parse(TimeFormatDirect, timestamp)
	if err != nil {
		c.ch_message <- fmt.Sprintf("e|:|%s: format: TimeFormatDirect  error: %s\n", mod_name, err.Error())
		dt, err = time.Parse(TimeFormatReverse, timestamp)
	}
  }
  if err != nil {
	return time.Now().Format(TimeFormat)
  } else {
	return dt.Format(TimeFormat)
  }
}
