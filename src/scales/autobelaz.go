package scales

import (
	"fmt"
	"math"
	db "reading_from_scales/src/database"
	"strconv"
	"strings"
)

func (c *Config) Processing_autobelazes(message string) error {
	weightStr := strings.TrimSpace(message)

	weightFloat, err := strconv.ParseFloat(weightStr, 64)
	if err != nil {
		return fmt.Errorf("не удалось преобразовать вес: %v", err)
	}

	weight := int(math.Round(weightFloat * 1000))

	kaw := db.Kep_analytics_weight{}
	kaw.Id_scales = fmt.Sprintf("%d", c.Id_scale)
	kaw.Timestamp = c.get_datetime("")
	kaw.Weight = fmt.Sprintf("%d", weight)
	kaw.Weight_platform_1 = kaw.Weight
	kaw.Weight_stabilized_1 = "1"

	select {
	case c.ch_db_message <- kaw:
	default:
	}
	return nil
}
