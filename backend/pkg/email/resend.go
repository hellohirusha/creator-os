package email

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"html/template"
	"net/http"
	"os"
	"time"
)

// ResendClient wraps the Resend API
type ResendClient struct {
	apiKey     string
	httpClient *http.Client
	fromEmail  string
	fromName   string
}

func NewResendClient() *ResendClient {
	return &ResendClient{
		apiKey: os.Getenv("RESEND_API_KEY"),
		httpClient: &http.Client{
			Timeout: 15 * time.Second,
		},
		fromEmail: os.Getenv("EMAIL_FROM"),
		fromName:  os.Getenv("EMAIL_FROM_NAME"),
	}
}

type SendEmailRequest struct {
	From    string   `json:"from"`
	To      []string `json:"to"`
	Subject string   `json:"subject"`
	HTML    string   `json:"html"`
	Text    string   `json:"text,omitempty"`
	ReplyTo string   `json:"reply_to,omitempty"`
	Tags    []Tag    `json:"tags,omitempty"`
}

type Tag struct {
	Name  string `json:"name"`
	Value string `json:"value"`
}

type SendEmailResponse struct {
	ID    string `json:"id"`
	Error string `json:"message,omitempty"`
}

// Send dispatches a single email via the Resend API
func (c *ResendClient) Send(ctx context.Context, req SendEmailRequest) (*SendEmailResponse, error) {
	if c.apiKey == "" {
		return nil, fmt.Errorf("RESEND_API_KEY is not set")
	}

	// Set from if not provided
	if req.From == "" {
		req.From = fmt.Sprintf("%s <%s>", c.fromName, c.fromEmail)
	}

	body, err := json.Marshal(req)
	if err != nil {
		return nil, err
	}

	httpReq, err := http.NewRequestWithContext(ctx, "POST",
		"https://api.resend.com/emails", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}

	httpReq.Header.Set("Authorization", "Bearer "+c.apiKey)
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("resend API request failed: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()

	var result SendEmailResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode resend response: %w", err)
	}

	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("resend API error %d: %s", resp.StatusCode, result.Error)
	}

	return &result, nil
}

// RenderTemplate renders a Go HTML template with the given data map
// templateStr: HTML string with {{.VariableName}} placeholders
// data: map of variable name to value
func RenderTemplate(templateStr string, data map[string]string) (string, error) {
	// Wrap data in a struct-like map for template access
	tmpl, err := template.New("email").
		Option("missingkey=zero"). // Empty string for missing keys instead of error
		Parse(templateStr)
	if err != nil {
		return "", fmt.Errorf("template parse error: %w", err)
	}

	// Convert map[string]string to map[string]interface{} for template
	tmplData := make(map[string]interface{})
	for k, v := range data {
		tmplData[k] = v
	}

	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, tmplData); err != nil {
		return "", fmt.Errorf("template render error: %w", err)
	}

	return buf.String(), nil
}

// WrapWithLayout wraps email content in the base layout HTML
// This gives all emails a consistent, professional look
func WrapWithLayout(content, storeName, previewText string) string {
	return fmt.Sprintf(`<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>%s</title>
    <!-- Preview text (shown in email client before opening) -->
    <span style="display:none;max-height:0;overflow:hidden;">%s</span>
</head>
<body style="margin:0;padding:0;background-color:#f5f5f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
    <table width="100%%" cellpadding="0" cellspacing="0" style="background:#f5f5f5;padding:40px 20px;">
        <tr>
            <td align="center">
                <!-- Email container -->
                <table width="600" cellpadding="0" cellspacing="0"
                       style="background:#ffffff;border-radius:12px;overflow:hidden;
                              box-shadow:0 2px 8px rgba(0,0,0,0.06);">

                    <!-- Header -->
                    <tr>
                        <td style="background:#111111;padding:24px 40px;">
                            <p style="margin:0;color:#ffffff;font-size:20px;font-weight:700;">
                                %s
                            </p>
                        </td>
                    </tr>

                    <!-- Content -->
                    <tr>
                        <td style="padding:40px;">
                            %s
                        </td>
                    </tr>

                    <!-- Footer -->
                    <tr>
                        <td style="background:#f9f9f9;padding:24px 40px;
                                   border-top:1px solid #eeeeee;">
                            <p style="margin:0;font-size:12px;color:#999999;text-align:center;">
                                You received this email from %s.<br>
                                <a href="{{.UnsubscribeURL}}" style="color:#999999;">Unsubscribe</a>
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>`,
		storeName,   // <title>
		previewText, // preview text span
		storeName,   // header logo/name
		content,     // main email body
		storeName,   // footer
	)
}
