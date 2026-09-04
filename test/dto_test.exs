defmodule Weheat.DTOTest do
  use ExUnit.Case, async: true

  alias Weheat.DTO

  test "parses zoned, zone-less and 7-digit fractional timestamps" do
    for {input, expected} <- [
          {"2026-09-03T12:00:00Z", ~U[2026-09-03 12:00:00Z]},
          {"2026-09-03T12:00:00.123+02:00", ~U[2026-09-03 10:00:00.123Z]},
          {"2026-09-03T12:00:00.1234567", ~U[2026-09-03 12:00:00.123456Z]}
        ] do
      dto = DTO.ReadUserMeDto.from_map(%{"id" => "x", "createdOn" => input})
      assert DateTime.compare(dto.created_on, expected) == :eq, input
    end
  end

  test "drops unknown keys and leaves missing ones nil" do
    dto = DTO.PaginationMetadata.from_map(%{"totalCount" => 3, "bogus" => 1})
    assert %DTO.PaginationMetadata{total_count: 3, page_size: nil} = dto
  end
end
