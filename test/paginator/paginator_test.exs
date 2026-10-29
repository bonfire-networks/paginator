defmodule PaginatorTest do
  use Paginator.DataCase, async: true
  doctest Paginator

  alias Paginator.Cursor

  setup :create_customers_and_payments

  test "paginates forward", %{
    payments: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
  } do
    opts = [cursor_fields: [charged_at: :asc, id: :asc], limit: 4]

    page = payments_by_charged_at() |> Repo.paginate(opts)
    assert to_ids(page.edges) == to_ids([p5, p4, p1, p6])
    assert page.page_info.end_cursor == encode_cursor(%{charged_at: p6.charged_at, id: p6.id})

    page = payments_by_charged_at() |> Repo.paginate(opts ++ [after: page.page_info.end_cursor])
    assert to_ids(page.edges) == to_ids([p7, p3, p10, p2])
    assert page.page_info.end_cursor == encode_cursor(%{charged_at: p2.charged_at, id: p2.id})

    page = payments_by_charged_at() |> Repo.paginate(opts ++ [after: page.page_info.end_cursor])
    assert to_ids(page.edges) == to_ids([p12, p8, p9, p11])
    assert page.page_info.end_cursor == nil
  end

  test "paginates forward with legacy cursor", %{
    payments: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
  } do
    opts = [cursor_fields: [charged_at: :asc, id: :asc], limit: 4]

    page = payments_by_charged_at() |> Repo.paginate(opts)
    assert to_ids(page.edges) == to_ids([p5, p4, p1, p6])
    assert %{charged_at: charged_at, id: id} = Cursor.maybe_decode(page.page_info.end_cursor)
    assert charged_at == p6.charged_at
    assert id == p6.id

    legacy_cursor = encode_legacy_cursor([charged_at, id])

    page = payments_by_charged_at() |> Repo.paginate(opts ++ [after: legacy_cursor])
    assert to_ids(page.edges) == to_ids([p7, p3, p10, p2])
    assert %{charged_at: charged_at, id: id} = Cursor.maybe_decode(page.page_info.end_cursor)
    assert charged_at == p2.charged_at
    assert id == p2.id

    legacy_cursor = encode_legacy_cursor([charged_at, id])

    page = payments_by_charged_at() |> Repo.paginate(opts ++ [after: legacy_cursor])
    assert to_ids(page.edges) == to_ids([p12, p8, p9, p11])
    assert page.page_info.end_cursor == nil
  end

  test "paginates backward", %{
    payments: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
  } do
    opts = [cursor_fields: [charged_at: :asc, id: :asc], limit: 4]

    page =
      payments_by_charged_at()
      |> Repo.paginate(opts ++ [before: encode_cursor(%{charged_at: p11.charged_at, id: p11.id})])

    assert to_ids(page.edges) == to_ids([p2, p12, p8, p9])
    assert page.page_info.start_cursor == encode_cursor(%{charged_at: p2.charged_at, id: p2.id})

    page = payments_by_charged_at() |> Repo.paginate(opts ++ [before: page.page_info.start_cursor])
    assert to_ids(page.edges) == to_ids([p6, p7, p3, p10])
    assert page.page_info.start_cursor == encode_cursor(%{charged_at: p6.charged_at, id: p6.id})

    page = payments_by_charged_at() |> Repo.paginate(opts ++ [before: page.page_info.start_cursor])
    assert to_ids(page.edges) == to_ids([p5, p4, p1])
    assert page.page_info.end_cursor == nil
    assert page.page_info.final_cursor == encode_cursor(%{charged_at: p1.charged_at, id: p1.id})
    assert page.page_info.start_cursor == nil
  end

  test "returns an empty page when there are no results" do
    page =
      payments_by_status("failed")
      |> Repo.paginate(cursor_fields: [charged_at: :asc, id: :asc], limit: 10)

    assert page.edges == []
    assert page.page_info.end_cursor == nil
    assert page.page_info.start_cursor == nil
  end

  test "reports page_count, final_cursor and a per-record cursor function", %{
    payments: {_p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, p11, _p12}
  } do
    opts = [cursor_fields: [charged_at: :asc, id: :asc], limit: 8]

    page = payments_by_charged_at() |> Repo.paginate(opts)
    assert page.page_info.page_count == 8
    assert page.page_info.final_cursor == nil

    [first | _] = page.edges

    assert page.page_info.cursor_for_record_fun.(first) ==
             encode_cursor(%{charged_at: first.charged_at, id: first.id})

    page = payments_by_charged_at() |> Repo.paginate(opts ++ [after: page.page_info.end_cursor])
    assert page.page_info.page_count == 4
    assert page.page_info.end_cursor == nil
    assert page.page_info.final_cursor == encode_cursor(%{charged_at: p11.charged_at, id: p11.id})
  end

  describe "paginate a collection of payments, sorting by charged_at" do
    test "sorts ascending without cursors", %{
      payments: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_charged_at()
        |> Repo.paginate(cursor_fields: [charged_at: :asc, id: :asc], limit: 50)

      assert to_ids(edges) == to_ids([p5, p4, p1, p6, p7, p3, p10, p2, p12, p8, p9, p11])
      assert info(page_info) == %PageInfo{end_cursor: nil, start_cursor: nil, limit: 50}
    end

    test "sorts ascending with before cursor", %{
      payments: {p1, p2, p3, _p4, _p5, p6, p7, p8, p9, p10, _p11, p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_charged_at()
        |> Repo.paginate(
          cursor_fields: [charged_at: :asc, id: :asc],
          before: encode_cursor(%{charged_at: p9.charged_at, id: p9.id}),
          limit: 8
        )

      assert to_ids(edges) == to_ids([p1, p6, p7, p3, p10, p2, p12, p8])

      assert info(page_info) == %PageInfo{
               end_cursor: encode_cursor(%{charged_at: p8.charged_at, id: p8.id}),
               start_cursor: encode_cursor(%{charged_at: p1.charged_at, id: p1.id}),
               limit: 8
             }
    end

    test "sorts ascending with after cursor", %{
      payments: {_p1, p2, p3, _p4, _p5, _p6, _p7, p8, p9, p10, p11, p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_charged_at()
        |> Repo.paginate(
          cursor_fields: [charged_at: :asc, id: :asc],
          after: encode_cursor(%{charged_at: p3.charged_at, id: p3.id}),
          limit: 8
        )

      assert to_ids(edges) == to_ids([p10, p2, p12, p8, p9, p11])

      assert info(page_info) == %PageInfo{
               start_cursor: encode_cursor(%{charged_at: p10.charged_at, id: p10.id}),
               limit: 8
             }
    end

    test "sorts ascending with before and after cursor", %{
      payments: {_p1, p2, p3, _p4, _p5, _p6, _p7, p8, _p9, p10, _p11, p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_charged_at()
        |> Repo.paginate(
          cursor_fields: [charged_at: :asc, id: :asc],
          after: encode_cursor(%{charged_at: p3.charged_at, id: p3.id}),
          before: encode_cursor(%{charged_at: p8.charged_at, id: p8.id}),
          limit: 8
        )

      assert to_ids(edges) == to_ids([p10, p2, p12])

      assert info(page_info) == %PageInfo{
               end_cursor: nil,
               start_cursor: encode_cursor(%{charged_at: p10.charged_at, id: p10.id}),
               limit: 8
             }

      assert page_info.final_cursor == encode_cursor(%{charged_at: p12.charged_at, id: p12.id})
    end

    test "sorts descending without cursors", %{
      payments: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_charged_at(:desc)
        |> Repo.paginate(cursor_fields: [charged_at: :desc, id: :desc], limit: 50)

      assert to_ids(edges) == to_ids([p11, p9, p8, p12, p2, p10, p3, p7, p6, p1, p4, p5])
      assert info(page_info) == %PageInfo{end_cursor: nil, start_cursor: nil, limit: 50}
    end

    test "sorts descending with before cursor", %{
      payments: {_p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, p9, _p10, p11, _p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_charged_at(:desc)
        |> Repo.paginate(
          cursor_fields: [charged_at: :desc, id: :desc],
          before: encode_cursor(%{charged_at: p9.charged_at, id: p9.id}),
          limit: 8
        )

      assert to_ids(edges) == to_ids([p11])

      assert info(page_info) == %PageInfo{end_cursor: nil, start_cursor: nil, limit: 8}
      assert page_info.final_cursor == encode_cursor(%{charged_at: p11.charged_at, id: p11.id})
    end

    test "sorts descending with after cursor", %{
      payments: {p1, p2, p3, _p4, _p5, p6, p7, p8, p9, p10, _p11, p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_charged_at(:desc)
        |> Repo.paginate(
          cursor_fields: [charged_at: :desc, id: :desc],
          after: encode_cursor(%{charged_at: p9.charged_at, id: p9.id}),
          limit: 8
        )

      assert to_ids(edges) == to_ids([p8, p12, p2, p10, p3, p7, p6, p1])

      assert info(page_info) == %PageInfo{
               end_cursor: encode_cursor(%{charged_at: p1.charged_at, id: p1.id}),
               start_cursor: encode_cursor(%{charged_at: p8.charged_at, id: p8.id}),
               limit: 8
             }
    end

    test "sorts descending with before and after cursor", %{
      payments: {_p1, p2, p3, _p4, _p5, _p6, _p7, p8, p9, p10, _p11, p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_charged_at(:desc)
        |> Repo.paginate(
          cursor_fields: [charged_at: :desc, id: :desc],
          after: encode_cursor(%{charged_at: p9.charged_at, id: p9.id}),
          before: encode_cursor(%{charged_at: p3.charged_at, id: p3.id}),
          limit: 8
        )

      assert to_ids(edges) == to_ids([p8, p12, p2, p10])

      assert info(page_info) == %PageInfo{
               end_cursor: nil,
               start_cursor: encode_cursor(%{charged_at: p8.charged_at, id: p8.id}),
               limit: 8
             }

      assert page_info.final_cursor == encode_cursor(%{charged_at: p10.charged_at, id: p10.id})
    end

    test "sorts ascending with before cursor at beginning of collection", %{
      payments: {_p1, _p2, _p3, _p4, p5, _p6, _p7, _p8, _p9, _p10, _p11, _p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_charged_at()
        |> Repo.paginate(
          cursor_fields: [charged_at: :asc, id: :asc],
          before: encode_cursor(%{charged_at: p5.charged_at, id: p5.id}),
          limit: 8
        )

      assert to_ids(edges) == to_ids([])
      assert info(page_info) == %PageInfo{end_cursor: nil, start_cursor: nil, limit: 8}
    end

    test "sorts ascending with after cursor at end of collection", %{
      payments: {_p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, p11, _p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_charged_at()
        |> Repo.paginate(
          cursor_fields: [charged_at: :asc, id: :asc],
          after: encode_cursor(%{charged_at: p11.charged_at, id: p11.id}),
          limit: 8
        )

      assert to_ids(edges) == to_ids([])
      assert info(page_info) == %PageInfo{end_cursor: nil, start_cursor: nil, limit: 8}
    end

    test "sorts descending with before cursor at beginning of collection", %{
      payments: {_p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, p11, _p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_charged_at(:desc)
        |> Repo.paginate(
          cursor_fields: [charged_at: :desc, id: :desc],
          before: encode_cursor(%{charged_at: p11.charged_at, id: p11.id}),
          limit: 8
        )

      assert to_ids(edges) == to_ids([])
      assert info(page_info) == %PageInfo{end_cursor: nil, start_cursor: nil, limit: 8}
    end

    test "sorts descending with after cursor at end of collection", %{
      payments: {_p1, _p2, _p3, _p4, p5, _p6, _p7, _p8, _p9, _p10, _p11, _p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_charged_at(:desc)
        |> Repo.paginate(
          cursor_fields: [charged_at: :desc, id: :desc],
          after: encode_cursor(%{charged_at: p5.charged_at, id: p5.id}),
          limit: 8
        )

      assert to_ids(edges) == to_ids([])
      assert info(page_info) == %PageInfo{end_cursor: nil, start_cursor: nil, limit: 8}
    end
  end

  describe "paginate a collection of payments with customer filter, sorting by amount, charged_at" do
    test "multiple cursor_fields with pre-existing where filter in query", %{
      customers: {c1, _c2, _c3},
      payments: {_p1, _p2, _p3, _p4, p5, p6, p7, p8, _p9, _p10, _p11, _p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        customer_payments_by_charged_at_and_amount(c1)
        |> Repo.paginate(cursor_fields: [charged_at: :asc, amount: :asc, id: :asc], limit: 2)

      assert to_ids(edges) == to_ids([p5, p6])

      %Page{edges: edges, page_info: _metadata} =
        customer_payments_by_charged_at_and_amount(c1)
        |> Repo.paginate(
          cursor_fields: [charged_at: :asc, amount: :asc, id: :asc],
          limit: 2,
          after: page_info.end_cursor
        )

      assert to_ids(edges) == to_ids([p7, p8])
    end

    test "before cursor with multiple cursor_fields and pre-existing where filter in query", %{
      customers: {c1, _c2, _c3},
      payments: {_p1, _p2, _p3, _p4, _p5, p6, _p7, _p8, _p9, _p10, _p11, _p12}
    } do
      assert %Page{edges: [], page_info: _metadata} =
               customer_payments_by_charged_at_and_amount(c1)
               |> Repo.paginate(
                 cursor_fields: [amount: :asc, charged_at: :asc, id: :asc],
                 before:
                   encode_cursor(%{amount: p6.amount, charged_at: p6.charged_at, id: p6.id}),
                 limit: 1
               )
    end
  end

  describe "paginate a collection of payments, sorting by customer name" do
    test "raises error when binding not found", %{
      payments: {_p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, p11, _p12}
    } do
      error =
        assert_raise ArgumentError, fn ->
          %Page{} =
            payments_by_customer_name()
            |> Repo.paginate(
              cursor_fields: [
                {{:bogus_binding, :id}, :asc},
                {{:bogus_binding, :name}, :asc}
              ],
              limit: 50,
              before:
                encode_cursor(%{
                  {:bogus_binding, :id} => p11.id,
                  {:bogus_binding, :name} => p11.customer.name
                })
            )
        end

      # the message prints the query's alias map, whose key order is not stable
      assert error.message =~ "Could not find binding `bogus_binding` in query aliases: %{"
      assert error.message =~ "customer: 1"
      assert error.message =~ "payments: 0"
    end

    test "sorts with mixed bindingless, bound columns", %{
      payments: {_p1, _p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, _p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_customer_name()
        |> Repo.paginate(
          cursor_fields: [{:id, :asc}, {{:customer, :name}, :asc}],
          before: encode_cursor(%{:id => p11.id, {:customer, :name} => p11.customer.name}),
          limit: 8
        )

      assert to_ids(edges) == to_ids([p3, p4, p5, p6, p7, p8, p9, p10])

      assert info(page_info) == %PageInfo{
               end_cursor:
                 encode_cursor(%{:id => p10.id, {:customer, :name} => p10.customer.name}),
               start_cursor: encode_cursor(%{:id => p3.id, {:customer, :name} => p3.customer.name}),
               limit: 8
             }
    end

    test "sorts ascending without cursors", %{
      payments: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_customer_name()
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :asc}, {{:customer, :name}, :asc}],
          limit: 50
        )

      assert to_ids(edges) == to_ids([p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12])
      assert info(page_info) == %PageInfo{end_cursor: nil, start_cursor: nil, limit: 50}
    end

    test "sorts ascending with before cursor", %{
      payments: {_p1, _p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, _p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_customer_name()
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :asc}, {{:customer, :name}, :asc}],
          before:
            encode_cursor(%{{:payments, :id} => p11.id, {:customer, :name} => p11.customer.name}),
          limit: 8
        )

      assert to_ids(edges) == to_ids([p3, p4, p5, p6, p7, p8, p9, p10])

      assert info(page_info) == %PageInfo{
               end_cursor:
                 encode_cursor(%{
                   {:payments, :id} => p10.id,
                   {:customer, :name} => p10.customer.name
                 }),
               start_cursor:
                 encode_cursor(%{
                   {:payments, :id} => p3.id,
                   {:customer, :name} => p3.customer.name
                 }),
               limit: 8
             }
    end

    test "sorts ascending with after cursor", %{
      payments: {_p1, _p2, _p3, _p4, _p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_customer_name()
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :asc}, {{:customer, :name}, :asc}],
          after:
            encode_cursor(%{{:payments, :id} => p6.id, {:customer, :name} => p6.customer.name}),
          limit: 8
        )

      assert to_ids(edges) == to_ids([p7, p8, p9, p10, p11, p12])

      assert info(page_info) == %PageInfo{
               start_cursor:
                 encode_cursor(%{
                   {:payments, :id} => p7.id,
                   {:customer, :name} => p7.customer.name
                 }),
               limit: 8
             }
    end

    test "sorts ascending with before and after cursor", %{
      payments: {_p1, _p2, _p3, _p4, _p5, p6, p7, p8, p9, p10, _p11, _p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_customer_name()
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :asc}, {{:customer, :name}, :asc}],
          after:
            encode_cursor(%{{:payments, :id} => p6.id, {:customer, :name} => p6.customer.name}),
          before:
            encode_cursor(%{{:payments, :id} => p10.id, {:customer, :name} => p10.customer.name}),
          limit: 8
        )

      assert to_ids(edges) == to_ids([p7, p8, p9])

      assert info(page_info) == %PageInfo{
               end_cursor: nil,
               start_cursor:
                 encode_cursor(%{
                   {:payments, :id} => p7.id,
                   {:customer, :name} => p7.customer.name
                 }),
               limit: 8
             }

      assert page_info.final_cursor ==
               encode_cursor(%{{:payments, :id} => p9.id, {:customer, :name} => p9.customer.name})
    end

    test "sorts descending without cursors", %{
      payments: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_customer_name(:desc, :desc)
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :desc}, {{:customer, :name}, :desc}],
          limit: 50
        )

      assert to_ids(edges) == to_ids([p12, p11, p10, p9, p8, p7, p6, p5, p4, p3, p2, p1])
      assert info(page_info) == %PageInfo{end_cursor: nil, start_cursor: nil, limit: 50}
    end

    test "sorts descending with before cursor", %{
      payments: {_p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, p11, p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_customer_name(:desc)
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :desc}, {{:customer, :name}, :desc}],
          before:
            encode_cursor(%{{:payments, :id} => p11.id, {:customer, :name} => p11.customer.name}),
          limit: 8
        )

      assert to_ids(edges) == to_ids([p12])

      assert info(page_info) == %PageInfo{end_cursor: nil, limit: 8}

      assert page_info.final_cursor ==
               encode_cursor(%{
                 {:payments, :id} => p12.id,
                 {:customer, :name} => p12.customer.name
               })
    end

    test "sorts descending with after cursor", %{
      payments: {_p1, _p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, _p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_customer_name(:desc, :desc)
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :desc}, {{:customer, :name}, :desc}],
          after:
            encode_cursor(%{{:payments, :id} => p11.id, {:customer, :name} => p11.customer.name}),
          limit: 8
        )

      assert to_ids(edges) == to_ids([p10, p9, p8, p7, p6, p5, p4, p3])

      assert info(page_info) == %PageInfo{
               end_cursor:
                 encode_cursor(%{
                   {:payments, :id} => p3.id,
                   {:customer, :name} => p3.customer.name
                 }),
               start_cursor:
                 encode_cursor(%{
                   {:payments, :id} => p10.id,
                   {:customer, :name} => p10.customer.name
                 }),
               limit: 8
             }
    end

    test "sorts descending with before and after cursor", %{
      payments: {_p1, _p2, _p3, _p4, _p5, p6, p7, p8, p9, p10, p11, _p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_customer_name(:desc, :desc)
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :desc}, {{:customer, :name}, :desc}],
          after:
            encode_cursor(%{{:payments, :id} => p11.id, {:customer, :name} => p11.customer.name}),
          before:
            encode_cursor(%{{:payments, :id} => p6.id, {:customer, :name} => p6.customer.name}),
          limit: 8
        )

      assert to_ids(edges) == to_ids([p10, p9, p8, p7])

      assert info(page_info) == %PageInfo{
               end_cursor: nil,
               start_cursor:
                 encode_cursor(%{
                   {:payments, :id} => p10.id,
                   {:customer, :name} => p10.customer.name
                 }),
               limit: 8
             }

      assert page_info.final_cursor ==
               encode_cursor(%{{:payments, :id} => p7.id, {:customer, :name} => p7.customer.name})
    end

    test "sorts ascending with before cursor at beginning of collection", %{
      payments: {p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, _p11, _p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_customer_name()
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :asc}, {{:customer, :name}, :asc}],
          before:
            encode_cursor(%{{:payments, :id} => p1.id, {:customer, :name} => p1.customer.name}),
          limit: 8
        )

      assert to_ids(edges) == to_ids([])
      assert info(page_info) == %PageInfo{end_cursor: nil, start_cursor: nil, limit: 8}
    end

    test "sorts ascending with after cursor at end of collection", %{
      payments: {_p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, _p11, p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_customer_name()
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :asc}, {{:customer, :name}, :asc}],
          after:
            encode_cursor(%{{:payments, :id} => p12.id, {:customer, :name} => p12.customer.name}),
          limit: 8
        )

      assert to_ids(edges) == to_ids([])
      assert info(page_info) == %PageInfo{end_cursor: nil, start_cursor: nil, limit: 8}
    end

    test "sorts descending with before cursor at beginning of collection", %{
      payments: {_p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, _p11, p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_customer_name(:desc, :desc)
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :desc}, {{:customer, :name}, :desc}],
          before:
            encode_cursor(%{{:payments, :id} => p12.id, {:customer, :name} => p12.customer.name}),
          limit: 8
        )

      assert to_ids(edges) == to_ids([])
      assert info(page_info) == %PageInfo{end_cursor: nil, start_cursor: nil, limit: 8}
    end

    test "sorts descending with after cursor at end of collection", %{
      payments: {p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, _p11, _p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_customer_name(:desc, :desc)
        |> Repo.paginate(
          cursor_fields: [{{:payments, :id}, :desc}, {{:customer, :name}, :desc}],
          after:
            encode_cursor(%{{:payments, :id} => p1.id, {:customer, :name} => p1.customer.name}),
          limit: 8
        )

      assert to_ids(edges) == to_ids([])
      assert info(page_info) == %PageInfo{end_cursor: nil, start_cursor: nil, limit: 8}
    end

    test "sorts on 2nd level join column with a custom cursor value function", %{
      payments: {_p1, _p2, _p3, _p4, p5, p6, p7, _p8, _p9, _p10, _p11, _p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_address_city()
        |> Repo.paginate(
          cursor_fields: [{{:address, :city}, :asc}, id: :asc],
          limit: 3,
          fetch_cursor_value_fun: fn
            schema, {:address, :city} ->
              schema.customer.address.city

            schema, field ->
              Paginator.default_fetch_cursor_value(schema, field)
          end
        )

      assert to_ids(edges) == to_ids([p5, p6, p7])

      p7 = Repo.preload(p7, customer: :address)

      assert info(page_info) == %PageInfo{
               end_cursor:
                 encode_cursor(%{{:address, :city} => p7.customer.address.city, :id => p7.id}),
               limit: 3
             }
    end

    test "sorts with respect to nil values", %{
      payments: {_p1, _p2, _p3, _p4, _p5, _p6, p7, _p8, _p9, _p10, p11, _p12}
    } do
      %Page{edges: edges, page_info: page_info} =
        payments_by_charged_at(:desc)
        |> Repo.paginate(
          cursor_fields: [charged_at: :desc, id: :desc],
          after: encode_cursor(%{charged_at: nil, id: nil}),
          limit: 8
        )

      assert Enum.count(edges) == 8

      assert info(page_info) == %PageInfo{
               start_cursor: encode_cursor(%{charged_at: p11.charged_at, id: p11.id}),
               limit: 8,
               end_cursor: encode_cursor(%{charged_at: p7.charged_at, id: p7.id})
             }
    end
  end

  test "applies a default limit if none is provided", %{
    payments: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}
  } do
    %Page{edges: edges, page_info: page_info} =
      payments_by_customer_name()
      |> Repo.paginate(cursor_fields: [id: :asc])

    assert to_ids(edges) == to_ids([p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12])
    assert info(page_info) == %PageInfo{end_cursor: nil, start_cursor: nil, limit: 50}
  end

  test "enforces the minimum limit", %{
    payments: {p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, _p11, _p12}
  } do
    %Page{edges: edges, page_info: page_info} =
      payments_by_customer_name()
      |> Repo.paginate(cursor_fields: [id: :asc], limit: 0)

    assert to_ids(edges) == to_ids([p1])
    assert info(page_info) == %PageInfo{end_cursor: encode_cursor(%{id: p1.id}), limit: 1}
  end

  describe "with include_total_count" do
    test "when set to :infinity", %{
      payments: {_p1, _p2, _p3, _p4, p5, _p6, _p7, _p8, _p9, _p10, _p11, _p12}
    } do
      %Page{page_info: page_info} =
        payments_by_customer_name()
        |> Repo.paginate(
          cursor_fields: [id: :asc],
          limit: 5,
          total_count_limit: :infinity,
          include_total_count: true
        )

      assert info(page_info) == %PageInfo{
               end_cursor: encode_cursor(%{id: p5.id}),
               limit: 5,
               total_count: 12,
               total_count_cap_exceeded: false
             }
    end

    test "when cap not exceeded", %{
      payments: {_p1, _p2, _p3, _p4, p5, _p6, _p7, _p8, _p9, _p10, _p11, _p12}
    } do
      %Page{page_info: page_info} =
        payments_by_customer_name()
        |> Repo.paginate(
          cursor_fields: [id: :asc],
          limit: 5,
          include_total_count: true
        )

      assert info(page_info) == %PageInfo{
               end_cursor: encode_cursor(%{id: p5.id}),
               limit: 5,
               total_count: 12,
               total_count_cap_exceeded: false
             }
    end

    test "when cap exceeded", %{
      payments: {_p1, _p2, _p3, _p4, p5, _p6, _p7, _p8, _p9, _p10, _p11, _p12}
    } do
      %Page{page_info: page_info} =
        payments_by_customer_name()
        |> Repo.paginate(
          cursor_fields: [id: :asc],
          limit: 5,
          include_total_count: true,
          total_count_limit: 10
        )

      assert info(page_info) == %PageInfo{
               end_cursor: encode_cursor(%{id: p5.id}),
               limit: 5,
               total_count: 10,
               total_count_cap_exceeded: true
             }
    end

    test "when custom total_count_primary_key_field", %{
      addresses: {_a1, a2, _a3}
    } do
      %Page{page_info: page_info} =
        from(a in Address, select: a)
        |> Repo.paginate(
          cursor_fields: [city: :asc],
          limit: 2,
          include_total_count: true,
          total_count_primary_key_field: :city
        )

      assert info(page_info) == %PageInfo{
               end_cursor: encode_cursor(%{city: a2.city}),
               limit: 2,
               total_count: 3,
               total_count_cap_exceeded: false
             }
    end
  end

  test "when before parameter is erlang term, we do not execute the code", %{} do
    # before and after, are user inputs, we need to make sure that they are
    # handled safely.

    test_pid = self()

    exploit = fn _, _ ->
      send(test_pid, :rce)
      {:cont, []}
    end

    payload =
      exploit
      |> :erlang.term_to_binary()
      |> Base.url_encode64()

    assert_raise(ArgumentError, ~r/^cannot deserialize.+/, fn ->
      payments_by_amount_and_charged_at(:asc, :desc)
      |> Repo.paginate(
        cursor_fields: [amount: :asc, charged_at: :desc, id: :asc],
        before: payload,
        limit: 3
      )
    end)

    refute_receive :rce, 1000, "Remote Code Execution Detected"
  end

  test "per-record cursor generation", %{
    payments: {p1, _p2, _p3, _p4, _p5, _p6, p7, _p8, _p9, _p10, _p11, _p12}
  } do
    assert Paginator.cursor_for_record(p1, charged_at: :asc, id: :asc) ==
             encode_cursor(%{charged_at: p1.charged_at, id: p1.id})

    assert Paginator.cursor_for_record(p7, amount: :asc) == encode_cursor(%{amount: p7.amount})
  end

  test "per-record cursor generation with custom cursor value function", %{
    payments: {p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, _p11, _p12}
  } do
    assert Paginator.cursor_for_record(p1, [charged_at: :asc, id: :asc], fn schema, field ->
             case field do
               :id -> Map.get(schema, :id)
               _ -> "10"
             end
           end) == encode_cursor(%{charged_at: "10", id: p1.id})
  end

  test "sorts on two different directions with before cursor", %{
    payments: {_p1, _p2, _p3, p4, p5, p6, p7, _p8, _p9, _p10, _p11, _p12}
  } do
    %Page{edges: edges, page_info: page_info} =
      payments_by_amount_and_charged_at(:asc, :desc)
      |> Repo.paginate(
        cursor_fields: [amount: :asc, charged_at: :desc, id: :asc],
        before: encode_cursor(%{amount: p7.amount, charged_at: p7.charged_at, id: p7.id}),
        limit: 3
      )

    assert to_ids(edges) == to_ids([p6, p4, p5])

    assert info(page_info) == %PageInfo{end_cursor: nil, start_cursor: nil, limit: 3}

    assert page_info.final_cursor ==
             encode_cursor(%{amount: p5.amount, charged_at: p5.charged_at, id: p5.id})
  end

  test "sorts on two different directions with after cursor", %{
    payments: {_p1, _p2, _p3, p4, p5, _p6, p7, p8, _p9, _p10, _p11, _p12}
  } do
    %Page{edges: edges, page_info: page_info} =
      payments_by_amount_and_charged_at(:asc, :desc)
      |> Repo.paginate(
        cursor_fields: [amount: :asc, charged_at: :desc, id: :asc],
        after: encode_cursor(%{amount: p4.amount, charged_at: p4.charged_at, id: p4.id}),
        limit: 3
      )

    assert to_ids(edges) == to_ids([p5, p7, p8])

    assert info(page_info) == %PageInfo{
             end_cursor: encode_cursor(%{amount: p8.amount, charged_at: p8.charged_at, id: p8.id}),
             start_cursor: encode_cursor(%{amount: p5.amount, charged_at: p5.charged_at, id: p5.id}),
             limit: 3
           }
  end

  test "sorts on two different directions with before and after cursor", %{
    payments: {_p1, _p2, _p3, p4, p5, p6, p7, p8, _p9, _p10, _p11, _p12}
  } do
    %Page{edges: edges, page_info: page_info} =
      payments_by_amount_and_charged_at(:desc, :asc)
      |> Repo.paginate(
        cursor_fields: [amount: :desc, charged_at: :asc, id: :asc],
        after: encode_cursor(%{amount: p8.amount, charged_at: p8.charged_at, id: p8.id}),
        before: encode_cursor(%{amount: p6.amount, charged_at: p6.charged_at, id: p6.id}),
        limit: 8
      )

    assert to_ids(edges) == to_ids([p7, p5, p4])

    assert info(page_info) == %PageInfo{
             end_cursor: nil,
             start_cursor: encode_cursor(%{amount: p7.amount, charged_at: p7.charged_at, id: p7.id}),
             limit: 8
           }

    assert page_info.final_cursor ==
             encode_cursor(%{amount: p4.amount, charged_at: p4.charged_at, id: p4.id})
  end

  # Postgres can't use `col > v OR col IS NULL` as an index condition, so bounds are plain comparisons unless the caller lists the field in `cursor_fields_nullable`. A nullable field that isn't listed would silently lose its null rows from later pages.
  describe "cursor_fields_nullable" do
    setup %{payments: {_p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8, _p9, _p10, p11, _p12}} do
      [after: encode_cursor(%{charged_at: p11.charged_at, id: p11.id})]
    end

    test "bounds are plain comparisons by default", %{after: after_cursor} do
      sql =
        payments_by_charged_at()
        |> Paginator.paginated_query(
          cursor_fields: [charged_at: :asc, id: :asc],
          after: after_cursor
        )
        |> to_sql()

      refute sql =~ "IS NULL"
    end

    test "only the listed fields keep the IS NULL escape", %{after: after_cursor} do
      sql =
        payments_by_charged_at()
        |> Paginator.paginated_query(
          cursor_fields: [charged_at: :asc, id: :asc],
          cursor_fields_nullable: [:charged_at],
          after: after_cursor
        )
        |> to_sql()

      assert sql =~ ~s("charged_at" IS NULL)
      refute sql =~ ~s("id" IS NULL)
    end

    test "rows with a null in a listed field still show up on later pages" do
      [null1, null2] = insert_list(2, :payment, charged_at: nil)

      ids =
        page_through(&payments_by_charged_at/0,
          cursor_fields: [charged_at: :asc, id: :asc],
          cursor_fields_nullable: [:charged_at],
          limit: 4
        )

      # Postgres sorts nulls last in ascending order
      assert Enum.take(ids, -2) == [null1.id, null2.id]
      assert length(ids) == 14
    end

    test "a null cursor value in an unlisted field logs a warning" do
      insert_list(2, :payment, charged_at: nil)

      # 12 dated payments + the first null one fill the page, so the cursor is built from a null row
      opts = [cursor_fields: [charged_at: :asc, id: :asc], limit: 13]

      # warnings only: the debug logs print the whole config, which has a `cursor_fields_nullable` key
      log =
        ExUnit.CaptureLog.capture_log([level: :warning], fn ->
          payments_by_charged_at() |> Repo.paginate(opts)
        end)

      assert log =~ "not listed in `cursor_fields_nullable`"

      log =
        ExUnit.CaptureLog.capture_log([level: :warning], fn ->
          payments_by_charged_at() |> Repo.paginate(opts ++ [cursor_fields_nullable: [:charged_at]])
        end)

      refute log =~ "cursor_fields_nullable"
    end
  end

  # `page_count`, `final_cursor` and `cursor_for_record_fun` are asserted in their own test, so the page_info comparisons above stay about the cursors and limits
  defp info(%PageInfo{} = page_info),
    do: %{page_info | page_count: nil, final_cursor: nil, cursor_for_record_fun: nil}

  defp to_ids(edges), do: Enum.map(edges, & &1.id)

  defp to_sql(query) do
    {sql, _params} = Ecto.Adapters.SQL.to_sql(:all, Repo, query)
    sql
  end

  # ids of every row, following `end_cursor` page by page
  defp page_through(query_fun, opts, after_cursor \\ nil, acc \\ [], depth \\ 0)

  defp page_through(_query_fun, _opts, _after_cursor, acc, depth) when depth > 20, do: acc

  defp page_through(query_fun, opts, after_cursor, acc, depth) do
    page_opts = if after_cursor, do: opts ++ [after: after_cursor], else: opts
    %Page{edges: edges, page_info: page_info} = query_fun.() |> Repo.paginate(page_opts)
    acc = acc ++ to_ids(edges)

    if page_info.end_cursor,
      do: page_through(query_fun, opts, page_info.end_cursor, acc, depth + 1),
      else: acc
  end

  defp create_customers_and_payments(_context) do
    c1 = insert(:customer, %{name: "Bob"})
    c2 = insert(:customer, %{name: "Alice"})
    c3 = insert(:customer, %{name: "Charlie"})

    a1 = insert(:address, city: "London", customer: c1)
    a2 = insert(:address, city: "New York", customer: c2)
    a3 = insert(:address, city: "Tokyo", customer: c3)

    p1 = insert(:payment, customer: c2, charged_at: days_ago(11))
    p2 = insert(:payment, customer: c2, charged_at: days_ago(6))
    p3 = insert(:payment, customer: c2, charged_at: days_ago(8))
    p4 = insert(:payment, customer: c2, amount: 2, charged_at: days_ago(12))

    p5 = insert(:payment, customer: c1, amount: 3, charged_at: days_ago(13))
    p6 = insert(:payment, customer: c1, amount: 2, charged_at: days_ago(10))
    p7 = insert(:payment, customer: c1, amount: 4, charged_at: days_ago(9))
    p8 = insert(:payment, customer: c1, amount: 5, charged_at: days_ago(4))

    p9 = insert(:payment, customer: c3, charged_at: days_ago(3))
    p10 = insert(:payment, customer: c3, charged_at: days_ago(7))
    p11 = insert(:payment, customer: c3, charged_at: days_ago(2))
    p12 = insert(:payment, customer: c3, charged_at: days_ago(5))

    {:ok,
     customers: {c1, c2, c3},
     addresses: {a1, a2, a3},
     payments: {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12}}
  end

  defp payments_by_status(status, direction \\ :asc) do
    from(
      p in Payment,
      where: p.status == ^status,
      order_by: [{^direction, p.charged_at}, {^direction, p.id}],
      select: p
    )
  end

  defp payments_by_amount_and_charged_at(amount_direction, charged_at_direction) do
    from(
      p in Payment,
      order_by: [
        {^amount_direction, p.amount},
        {^charged_at_direction, p.charged_at},
        {:asc, p.id}
      ],
      select: p
    )
  end

  defp payments_by_charged_at(direction \\ :asc) do
    from(
      p in Payment,
      order_by: [{^direction, p.charged_at}, {^direction, p.id}],
      select: p
    )
  end

  defp payments_by_customer_name(payment_id_direction \\ :asc, customer_name_direction \\ :asc) do
    from(
      p in Payment,
      as: :payments,
      join: c in assoc(p, :customer),
      as: :customer,
      preload: [customer: c],
      select: p,
      order_by: [
        {^customer_name_direction, c.name},
        {^payment_id_direction, p.id}
      ]
    )
  end

  defp payments_by_address_city(payment_id_direction \\ :asc, address_city_direction \\ :asc) do
    from(
      p in Payment,
      as: :payments,
      join: c in assoc(p, :customer),
      as: :customer,
      join: a in assoc(c, :address),
      as: :address,
      preload: [customer: {c, address: a}],
      select: p,
      order_by: [
        {^address_city_direction, a.city},
        {^payment_id_direction, p.id}
      ]
    )
  end

  defp customer_payments_by_charged_at_and_amount(customer, direction \\ :asc) do
    from(
      p in Payment,
      where: p.customer_id == ^customer.id,
      order_by: [{^direction, p.charged_at}, {^direction, p.amount}, {^direction, p.id}]
    )
  end

  defp encode_cursor(value) do
    Cursor.maybe_encode(value)
  end

  defp encode_legacy_cursor(value) when is_list(value) do
    value
    |> :erlang.term_to_binary()
    |> Base.url_encode64()
  end

  defp days_ago(days) do
    DateTime.add(
      DateTime.utc_now(),
      -(days * 86400),
      :second
    )
  end
end
