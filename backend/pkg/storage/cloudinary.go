package storage

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"
)

type CloudinaryService struct {
	CloudName string
	APIKey    string
	APISecret string
}

func NewCloudinaryService() *CloudinaryService {
	return &CloudinaryService{
		CloudName: os.Getenv("CLOUDINARY_CLOUD_NAME"),
		APIKey:    os.Getenv("CLOUDINARY_API_KEY"),
		APISecret: os.Getenv("CLOUDINARY_API_SECRET"),
	}
}

type UploadResult struct {
	PublicID string `json:"public_id"`
	URL      string `json:"secure_url"`
	Width    int    `json:"width"`
	Height   int    `json:"height"`
	Format   string `json:"format"`
	Bytes    int    `json:"bytes"`
}

// UploadImage uploads an image file to Cloudinary
// folder: "products/tenant_id" organizes uploads by tenant
func (c *CloudinaryService) UploadImage(ctx context.Context, file io.Reader, folder string) (*UploadResult, error) {
	// Read file into buffer (needed for multipart form)
	buf, err := io.ReadAll(file)
	if err != nil {
		return nil, fmt.Errorf("failed to read file: %w", err)
	}

	// Build signed request parameters
	timestamp := strconv.FormatInt(time.Now().Unix(), 10)
	params := map[string]string{
		"folder":    folder,
		"timestamp": timestamp,
	}

	signature := c.sign(params)

	// Build multipart form
	var body bytes.Buffer
	writer := multipart.NewWriter(&body)

	// Add file
	part, err := writer.CreateFormFile("file", "image")
	if err != nil {
		return nil, err
	}
	part.Write(buf)

	// Add parameters
	for k, v := range params {
		writer.WriteField(k, v)
	}
	writer.WriteField("api_key", c.APIKey)
	writer.WriteField("signature", signature)
	writer.Close()

	// Upload to Cloudinary
	url := fmt.Sprintf("https://api.cloudinary.com/v1_1/%s/image/upload", c.CloudName)
	req, err := http.NewRequestWithContext(ctx, "POST", url, &body)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", writer.FormDataContentType())

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("upload request failed: %w", err)
	}
	defer resp.Body.Close()

	var result UploadResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	if result.URL == "" {
		return nil, fmt.Errorf("upload failed: no URL in response")
	}

	return &result, nil
}

// GeneratePresignedURL creates a signed URL for direct browser uploads
// (avoids routing large files through your backend)
func (c *CloudinaryService) GeneratePresignedURL(folder string) map[string]string {
	timestamp := strconv.FormatInt(time.Now().Unix(), 10)
	params := map[string]string{
		"folder":    folder,
		"timestamp": timestamp,
	}

	return map[string]string{
		"upload_url": fmt.Sprintf("https://api.cloudinary.com/v1_1/%s/image/upload", c.CloudName),
		"api_key":    c.APIKey,
		"timestamp":  timestamp,
		"folder":     folder,
		"signature":  c.sign(params),
	}
}

// sign generates HMAC-SHA1 signature for Cloudinary API calls
func (c *CloudinaryService) sign(params map[string]string) string {
	// Sort params alphabetically and concatenate
	keys := make([]string, 0, len(params))
	for k := range params {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	var parts []string
	for _, k := range keys {
		parts = append(parts, fmt.Sprintf("%s=%s", k, params[k]))
	}

	stringToSign := strings.Join(parts, "&") + c.APISecret

	mac := hmac.New(sha1.New, []byte(c.APISecret))
	mac.Write([]byte(stringToSign))
	return hex.EncodeToString(mac.Sum(nil))
}
