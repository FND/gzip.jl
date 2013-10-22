using Base.Test
include("gzip.jl")

let
  file = open("test/gunzip.c.gz", "r")
  bs = BitStream(file)
  @test read_bits_inv(bs, 5) == 31
  @test read_bits_inv(bs, 5) == 24
  @test read_bits_inv(bs, 4) == 2
  close(file)
end

let
    flags = 0b10001
    @test has_ext(flags)
    @test !has_crc(flags)
    @test !has_extra(flags)
    @test !has_name(flags)
    @test has_comment(flags)
end

let
  file = open("test/gunzip.c.gz", "r")
  h = read(file, GzipHeader)
  close(file)
end

let
  file = open("test/gunzip.c.gz", "r")
  h = read(file, GzipFile)
  @test h.fname == "gunzip.c"
  close(file)
end

let
  file = open("test/gunzip.c.gz", "r")
  h = read(file, GzipFile)
  bs = BitStream(file)
  bf = read(bs, BlockFormat)
  @test bf.last
  @test bf.block_type == [0,1]
  close(file)
end

let
  file = open("test/gunzip.c.gz", "r")
  read(file, GzipFile)
  bs = BitStream(file)
  bf = read(bs, BlockFormat)

  # These are the real values!
  huff_head = read(bs, HuffmanHeader)
  @test huff_head.hlit == 23
  @test huff_head.hdist == 27
  @test huff_head.hclen == 8
  close(file)
end


let
    file = open("test/gunzip.c.gz", "r")
    read(file, GzipFile)
    bs = BitStream(file)
    bf = read(bs, BlockFormat)

    head = read(bs, HuffmanHeader)
    hclens = [read_bits_inv(bs, 3) for i=1:(head.hclen+4)]
  
    labels = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]
    code_table = create_code_table(hclens, labels)
    tree = create_huffman_tree(code_table)

    for (label, code) = code_table
         assert(tree[code] == label)
    end
end

let 
    file = open("test/gunzip.c.gz")
    read(file, GzipFile)
    bs = BitStream(file)
    read(bs, BlockFormat)
    head = read(bs, HuffmanHeader)
    tree = read_first_tree(bs, head.hclen)
end

let 
    code_f = open("test/code_lengths.txt")
    real_code_strs = split(readall(code_f), '\n')
    real_codes = [convert(Uint8, int(x)) for x=real_code_strs[1:308]]
    file = open("test/gunzip.c.gz")
    read(file, GzipFile)
    bs = BitStream(file)
    read(bs, BlockFormat)
    head = read(bs, HuffmanHeader)
    tree = read_first_tree(bs, head.hclen)
    codes = read_second_tree_codes(bs, head, tree)
    @test codes == real_codes
end
