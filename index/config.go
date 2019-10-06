package index

type IndexConfig struct {
	Host string
	Port int
}

func NewIndexConfig() *IndexConfig {
	return &IndexConfig{
		Host: "localhost",
		Port: 6080,
	}
}
