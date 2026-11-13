// Copyright 2026 Han Li and contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Package common holds the helpers shared by the Linux and Windows E2E
// suites: building the plugin archive, installing vfox, running host
// commands, and small assertions. The actual scenarios live in the per-OS
// packages, so the workflow only has to run `go test`.
package common

import (
	"archive/tar"
	"archive/zip"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"testing"
	"time"
)

const (
	VfoxVersion = "1.1.0"

	linuxVfoxURL    = "https://github.com/version-fox/vfox/releases/download/v" + VfoxVersion + "/vfox_" + VfoxVersion + "_linux_x86_64.tar.gz"
	linuxVfoxSHA256 = "3b33c3c468b27bc17aecf0d6d3af24fe49fe204972984904a136a47b402a0ee4"

	windowsVfoxURL    = "https://github.com/version-fox/vfox/releases/download/v" + VfoxVersion + "/vfox_" + VfoxVersion + "_windows_x86_64.zip"
	windowsVfoxSHA256 = "1bbec8fffddbb62de0d93030c3f6203c69680662bc65257ca4a5e611cb607d0a"
)

var ansi = regexp.MustCompile(`\x1b\[[0-9;]*[A-Za-z]`)

// RepoRoot resolves the repository root from a test in tests/e2e/<os>.
func RepoRoot(t testing.TB) string {
	t.Helper()
	root, err := filepath.Abs(filepath.Join("..", "..", ".."))
	if err != nil {
		t.Fatalf("resolve repository root: %v", err)
	}
	return root
}

// BuildPluginZip packages the plugin exactly as `vfox add --source` expects:
// metadata.lua, hooks/, lib/ and the bundled WiX tools under bin/.
func BuildPluginZip(t testing.TB, repoRoot string) string {
	t.Helper()
	dest := filepath.Join(t.TempDir(), "python-plugin.zip")
	file, err := os.Create(dest)
	if err != nil {
		t.Fatalf("create plugin zip: %v", err)
	}
	writer := zip.NewWriter(file)
	for _, name := range []string{"metadata.lua", "hooks", "lib", "bin"} {
		root := filepath.Join(repoRoot, name)
		err := filepath.WalkDir(root, func(path string, entry os.DirEntry, walkErr error) error {
			if walkErr != nil {
				return walkErr
			}
			if entry.IsDir() {
				return nil
			}
			relative, err := filepath.Rel(repoRoot, path)
			if err != nil {
				return err
			}
			out, err := writer.Create(filepath.ToSlash(relative))
			if err != nil {
				return err
			}
			in, err := os.Open(path)
			if err != nil {
				return err
			}
			defer in.Close()
			_, err = io.Copy(out, in)
			return err
		})
		if err != nil {
			_ = writer.Close()
			_ = file.Close()
			t.Fatalf("add %s to plugin zip: %v", name, err)
		}
	}
	if err := writer.Close(); err != nil {
		t.Fatalf("close plugin zip: %v", err)
	}
	if err := file.Close(); err != nil {
		t.Fatalf("close plugin zip file: %v", err)
	}
	return dest
}

// InstallVfox downloads the pinned vfox release, verifies its checksum and
// places the executable in <home>/bin. It returns that bin directory.
func InstallVfox(t testing.TB, home string) string {
	t.Helper()
	bin := filepath.Join(home, "bin")
	if err := os.MkdirAll(bin, 0o755); err != nil {
		t.Fatalf("create vfox bin directory: %v", err)
	}

	url, checksum := linuxVfoxURL, linuxVfoxSHA256
	if runtime.GOOS == "windows" {
		url, checksum = windowsVfoxURL, windowsVfoxSHA256
	}
	archive := filepath.Join(t.TempDir(), filepath.Base(url))
	download(t, url, archive)
	verifySHA256(t, archive, checksum)

	if runtime.GOOS == "windows" {
		extractZipFile(t, archive, "vfox.exe", filepath.Join(bin, "vfox.exe"))
	} else {
		extractTarFile(t, archive, "vfox", filepath.Join(bin, "vfox"))
		if err := os.Chmod(filepath.Join(bin, "vfox"), 0o755); err != nil {
			t.Fatalf("make vfox executable: %v", err)
		}
	}
	return bin
}

func download(t testing.TB, url, dest string) {
	t.Helper()
	client := &http.Client{Timeout: 5 * time.Minute}
	response, err := client.Get(url)
	if err != nil {
		t.Fatalf("download %s: %v", url, err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		t.Fatalf("download %s: HTTP %d", url, response.StatusCode)
	}
	file, err := os.Create(dest)
	if err != nil {
		t.Fatalf("create %s: %v", dest, err)
	}
	defer file.Close()
	if _, err := io.Copy(file, response.Body); err != nil {
		t.Fatalf("write %s: %v", dest, err)
	}
}

func verifySHA256(t testing.TB, path, want string) {
	t.Helper()
	file, err := os.Open(path)
	if err != nil {
		t.Fatalf("open %s: %v", path, err)
	}
	defer file.Close()
	hash := sha256.New()
	if _, err := io.Copy(hash, file); err != nil {
		t.Fatalf("hash %s: %v", path, err)
	}
	got := hex.EncodeToString(hash.Sum(nil))
	if got != want {
		t.Fatalf("checksum mismatch for %s: got %s, want %s", path, got, want)
	}
}

func extractTarFile(t testing.TB, archive, baseName, dest string) {
	t.Helper()
	file, err := os.Open(archive)
	if err != nil {
		t.Fatalf("open %s: %v", archive, err)
	}
	defer file.Close()
	gzipReader, err := gzip.NewReader(file)
	if err != nil {
		t.Fatalf("open gzip %s: %v", archive, err)
	}
	defer gzipReader.Close()
	reader := tar.NewReader(gzipReader)
	for {
		header, err := reader.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			t.Fatalf("read %s: %v", archive, err)
		}
		if header.Typeflag != tar.TypeReg || filepath.Base(header.Name) != baseName {
			continue
		}
		writeReader(t, dest, reader)
		return
	}
	t.Fatalf("%s not found in %s", baseName, archive)
}

func extractZipFile(t testing.TB, archive, baseName, dest string) {
	t.Helper()
	reader, err := zip.OpenReader(archive)
	if err != nil {
		t.Fatalf("open %s: %v", archive, err)
	}
	defer reader.Close()
	for _, file := range reader.File {
		if file.FileInfo().IsDir() || filepath.Base(file.Name) != baseName {
			continue
		}
		in, err := file.Open()
		if err != nil {
			t.Fatalf("open %s in %s: %v", file.Name, archive, err)
		}
		writeReader(t, dest, in)
		_ = in.Close()
		return
	}
	t.Fatalf("%s not found in %s", baseName, archive)
}

func writeReader(t testing.TB, dest string, reader io.Reader) {
	t.Helper()
	file, err := os.Create(dest)
	if err != nil {
		t.Fatalf("create %s: %v", dest, err)
	}
	defer file.Close()
	if _, err := io.Copy(file, reader); err != nil {
		t.Fatalf("write %s: %v", dest, err)
	}
}

// HomeEnv returns the environment for a test that owns a temporary vfox
// home and the vfox executable in <home>/bin.
func HomeEnv(home, bin string) map[string]string {
	env := map[string]string{
		"HOME":        home,
		"USERPROFILE": home,
		"VFOX_HOME":   filepath.Join(home, ".vfox"),
		"PATH":        bin + string(os.PathListSeparator) + os.Getenv("PATH"),
	}
	for _, name := range []string{"GITHUB_TOKEN", "GH_TOKEN"} {
		if value := os.Getenv(name); value != "" {
			env[name] = value
		}
	}
	return env
}

// Run executes a command and returns its combined output.
func Run(dir string, env map[string]string, name string, args ...string) (string, error) {
	command := exec.Command(name, args...)
	command.Dir = dir
	command.Env = MergeEnv(env)
	output, err := command.CombinedOutput()
	return string(output), err
}

// RunOK executes a command and fails the test on a non-zero exit.
func RunOK(t testing.TB, dir string, env map[string]string, name string, args ...string) string {
	t.Helper()
	output, err := Run(dir, env, name, args...)
	if err != nil {
		t.Fatalf("%s %s failed: %v\n--- output ---\n%s", name, strings.Join(args, " "), err, output)
	}
	return output
}

// RunShell runs a bash or PowerShell script on the host, depending on GOOS.
func RunShell(dir string, env map[string]string, script string) (string, error) {
	if runtime.GOOS == "windows" {
		return Run(dir, env, "pwsh", "-NoProfile", "-Command", script)
	}
	return Run(dir, env, "bash", "-c", script)
}

// RunShellOK runs a host shell script and fails the test on a non-zero exit.
func RunShellOK(t testing.TB, dir string, env map[string]string, script string) string {
	t.Helper()
	output, err := RunShell(dir, env, script)
	if err != nil {
		t.Fatalf("shell script failed: %v\n--- script ---\n%s\n--- output ---\n%s", err, script, output)
	}
	return output
}

// MergeEnv overlays extra on the current process environment. Windows keys
// are case-insensitive, so PATH replaces Path instead of appearing twice.
func MergeEnv(extra map[string]string) []string {
	values := map[string]string{}
	keyFor := func(key string) string {
		if runtime.GOOS == "windows" {
			return strings.ToUpper(key)
		}
		return key
	}
	for _, item := range os.Environ() {
		key, value, found := strings.Cut(item, "=")
		if !found {
			continue
		}
		values[keyFor(key)] = key + "=" + value
	}
	for key, value := range extra {
		values[keyFor(key)] = key + "=" + value
	}
	result := make([]string, 0, len(values))
	for _, item := range values {
		result = append(result, item)
	}
	return result
}

// NewestUvBuildVersion asks the uv-build index for the newest CPython 3.11
// build with a downloadable archive for this OS.
func NewestUvBuildVersion(t testing.TB) string {
	t.Helper()
	osName := runtime.GOOS
	if osName != "windows" {
		osName = "linux"
	}
	url := "https://vault.vfox.dev/python/uv-build?os=" + osName + "&arch=x86_64"
	request, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		t.Fatalf("build uv-build request: %v", err)
	}
	request.Header.Set("User-Agent", "vfox")
	client := &http.Client{Timeout: 30 * time.Second}
	response, err := client.Do(request)
	if err != nil {
		t.Fatalf("fetch uv-build index: %v", err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		t.Fatalf("fetch uv-build index: HTTP %d", response.StatusCode)
	}
	var body struct {
		Items []struct {
			Implementation string `json:"implementation"`
			Variant        string `json:"variant"`
			Version        string `json:"version"`
			Filename       string `json:"filename"`
		} `json:"items"`
	}
	if err := json.NewDecoder(response.Body).Decode(&body); err != nil {
		t.Fatalf("decode uv-build index: %v", err)
	}
	best := ""
	for _, item := range body.Items {
		if item.Implementation != "cpython" || (item.Variant != "" && item.Variant != "default") {
			continue
		}
		if !strings.HasPrefix(item.Version, "3.11.") {
			continue
		}
		if !strings.HasSuffix(item.Filename, ".tar.gz") && !strings.HasSuffix(item.Filename, ".zip") {
			continue
		}
		if best == "" || versionLess(best, item.Version) {
			best = item.Version
		}
	}
	if best == "" {
		t.Fatalf("no CPython 3.11 uv-build archive for %s", osName)
	}
	return best
}

// MinorVersion returns the major.minor part of a dotted version, such as
// "3.11" for "3.11.18".
func MinorVersion(version string) string {
	parts := strings.SplitN(version, ".", 3)
	if len(parts) < 2 {
		return version
	}
	return parts[0] + "." + parts[1]
}

func versionLess(left, right string) bool {
	leftParts := strings.Split(left, ".")
	rightParts := strings.Split(right, ".")
	for i := 0; i < len(leftParts) && i < len(rightParts); i++ {
		l, errLeft := strconv.Atoi(leftParts[i])
		r, errRight := strconv.Atoi(rightParts[i])
		if errLeft != nil || errRight != nil {
			return left < right
		}
		if l != r {
			return l < r
		}
	}
	return len(leftParts) < len(rightParts)
}

func StripANSI(value string) string {
	return ansi.ReplaceAllString(value, "")
}

func RequireContains(t testing.TB, output, want, label string) {
	t.Helper()
	if !strings.Contains(StripANSI(output), want) {
		t.Fatalf("%s: missing %q\n--- output ---\n%s", label, want, output)
	}
}

func BashQuote(value string) string {
	return "'" + strings.ReplaceAll(value, "'", `'\''`) + "'"
}

func PowerShellQuote(value string) string {
	return "'" + strings.ReplaceAll(value, "'", "''") + "'"
}
