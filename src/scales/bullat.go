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
  //msg := regexp.MustCompile("(?m)^.*?<(.*?)>.*?$").FindStringSubmatch(message)
  //msg := regexp.MustCompile("^.*?<(.*?)>.*?$").FindStringSubmatch(message)
  //msg := regexp.MustCompile("^.*(<.*>).*").FindAllStringSubmatch(message, -1)
  msg := regexp.MustCompile("(?m).*<(.*)>[\\n\\r]+.*").ReplaceAllString(message, "$1")

  values := strings.Split(msg, ";")

  _timestamp := c.get_datetime(values[0])

  if DEBUG.enable {
    c.ch_message <- fmt.Sprintf("d|:|%s: ProcessingBullat message: %#v", mod_name, msg)
//	c.ch_message <- fmt.Sprintf("d|:|%s: ProcessingBullat message: %#v", mod_name, _msg)
	c.ch_message <- fmt.Sprintf("d|:|%s: ProcessingBullat values: %#v", mod_name, values)
	c.ch_message <- fmt.Sprintf("d|:|%s: _timestamp: %#v", mod_name, _timestamp)
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
