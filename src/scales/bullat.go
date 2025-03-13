package scales

import (
	"fmt"
	"regexp"
)

func (c *Config) ProcessingBullat(message string) {


  if DEBUG.enable {
    c.ch_message <- fmt.Sprintf("d|:|%s: ProcessingBullat: %#v", mod_name, message)
  }
}
