package models

import (
	"time"
)

type Product struct {
	ID             string    `json:"id"`
	TenantID       string    `json:"tenant_id"`
	CategoryID     *string   `json:"category_id,omitempty"`
	Name           string    `json:"name"`
	Slug           string    `json:"slug"`
	Description    *string   `json:"description,omitempty"`
	ShortDesc      *string   `json:"short_desc,omitempty"`
	BasePrice      float64   `json:"base_price"`
	ComparePrice   *float64  `json:"compare_price,omitempty"`
	Status         string    `json:"status"`
	IsFeatured     bool      `json:"is_featured"`
	Tags           []string  `json:"tags"`
	AIDescription  *string   `json:"ai_description,omitempty"`
	AIQualityScore *float64  `json:"ai_quality_score,omitempty"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`

	// Loaded separately (not in main SELECT)
	Images   []ProductImage   `json:"images,omitempty"`
	Variants []ProductVariant `json:"variants,omitempty"`
}

type ProductImage struct {
	ID        string    `json:"id"`
	ProductID string    `json:"product_id"`
	URL       string    `json:"url"`
	AltText   *string   `json:"alt_text,omitempty"`
	Position  int       `json:"position"`
	Width     *int      `json:"width,omitempty"`
	Height    *int      `json:"height,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

type ProductVariant struct {
	ID             string    `json:"id"`
	ProductID      string    `json:"product_id"`
	SKU            string    `json:"sku"`
	Title          string    `json:"title"`
	Option1Name    *string   `json:"option1_name,omitempty"`
	Option1Value   *string   `json:"option1_value,omitempty"`
	Option2Name    *string   `json:"option2_name,omitempty"`
	Option2Value   *string   `json:"option2_value,omitempty"`
	Price          float64   `json:"price"`
	ComparePrice   *float64  `json:"compare_price,omitempty"`
	StockQuantity  int       `json:"stock_quantity"`
	TrackInventory bool      `json:"track_inventory"`
	AllowBackorder bool      `json:"allow_backorder"`
	IsActive       bool      `json:"is_active"`
	Position       int       `json:"position"`
	ImageURL       *string   `json:"image_url,omitempty"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

// IsInStock returns true if the variant can be purchased right now
func (v *ProductVariant) IsInStock() bool {
	if !v.TrackInventory {
		return true
	}
	if v.AllowBackorder {
		return true
	}
	return v.StockQuantity > 0
}

// IsLowStock returns true if stock is at or below the alert threshold
func (v *ProductVariant) IsLowStock(threshold int) bool {
	if !v.TrackInventory {
		return false
	}
	return v.StockQuantity <= threshold
}
