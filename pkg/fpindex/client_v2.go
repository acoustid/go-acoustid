package fpindex

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/url"

	pb "github.com/acoustid/go-acoustid/proto/index"
)

type ClientV2 struct {
	client  *http.Client
	baseUrl url.URL
}

func NewClientV2(baseUrl url.URL) *ClientV2 {
	return &ClientV2{
		client: &http.Client{
			Transport: &http.Transport{},
			Jar:       nil,
		},
		baseUrl: baseUrl,
	}
}

type searchRequestJSON struct {
	Query []uint32 `json:"query"`
	Limit int      `json:"limit"`
}

type searchResultJSON struct {
	ID    uint32 `json:"id"`
	Score uint32 `json:"score"`
}

type searchResponseJSON struct {
	Results []searchResultJSON `json:"results"`
}

func (c *ClientV2) Close(ctx context.Context) {
	_ = ctx
}

func (c *ClientV2) Search(ctx context.Context, in *pb.SearchRequest) (*pb.SearchResponse, error) {
	body, err := json.Marshal(searchRequestJSON{Query: in.Hashes})
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest("POST", c.baseUrl.JoinPath("/main/_search").String(), bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Add("Content-Type", "application/json")
	req.Header.Add("Accept", "application/json")

	resp, err := c.client.Do(req.WithContext(ctx))
	if err != nil {
		return nil, err
	}
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var respJson searchResponseJSON
	err = json.Unmarshal(respBody, &respJson)
	if err != nil {
		return nil, err
	}

	results := make([]*pb.Result, len(respJson.Results))
	for i, r := range respJson.Results {
		results[i] = &pb.Result{
			Id:   r.ID,
			Hits: r.Score,
		}
	}
	return &pb.SearchResponse{Results: results}, nil
}
