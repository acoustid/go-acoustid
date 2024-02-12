package chromaprint

import (
	"bytes"
	"encoding/json"
	"fmt"
	"math"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

func FingerprintFile(path string, duration int) (AudioFileFingerprint, error) {
	cmd := exec.Command("fpcalc", "-length", strconv.Itoa(duration), "-json", path)

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	var result AudioFileFingerprint

	err := cmd.Run()
	if err != nil {
		return result, fmt.Errorf("fpcalc failed: %w: %v", err, strings.TrimSpace(stderr.String()))
	}

	var output struct {
		Duration    float64 `json:"duration"`
		Fingerprint string  `json:"fingerprint"`
	}

	err = json.Unmarshal(stdout.Bytes(), &output)
	if err != nil {
		return result, fmt.Errorf("invalid JSON output from fpcalc: %w", err)
	}

	result.Duration = time.Duration(math.Floor(1000*output.Duration+0.5)) * time.Millisecond
	fingerprint, err := ParseFingerprintString(output.Fingerprint)
	if err != nil {
		return result, err
	}
	result.Fingerprint = fingerprint

	return result, nil
}
