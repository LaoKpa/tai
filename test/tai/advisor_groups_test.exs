defmodule Tai.AdvisorGroupsTest do
  use ExUnit.Case, async: true
  doctest Tai.AdvisorGroups

  defmodule TestFactoryA do
    def advisor_specs(group, products) do
      products
      |> Enum.map(fn p ->
        order_books = %{} |> Map.put(p.venue_id, [p.symbol])

        {
          TestAdvisor,
          [
            group_id: group.id,
            advisor_id: :"advisor_#{p.venue_id}_#{p.symbol}",
            order_books: order_books,
            config: %{}
          ]
        }
      end)
    end
  end

  describe ".parse_config" do
    test "returns an ok tuple with a list of advisor groups" do
      config =
        Tai.Config.parse(
          advisor_groups: %{
            group_a: [
              advisor: AdvisorA,
              factory: TestFactoryA,
              products: "*",
              config: %{min_profit: 0.1}
            ],
            group_b: [
              advisor: AdvisorB,
              factory: TestFactoryB,
              products: "btc_usdt"
            ]
          }
        )

      assert {:ok, groups} = Tai.AdvisorGroups.parse_config(config)
      assert Enum.count(groups) == 2

      assert groups |> List.first() == %Tai.AdvisorGroup{
               id: :group_a,
               advisor: AdvisorA,
               factory: TestFactoryA,
               products: "*",
               config: %{min_profit: 0.1}
             }

      assert groups |> List.last() == %Tai.AdvisorGroup{
               id: :group_b,
               advisor: AdvisorB,
               factory: TestFactoryB,
               products: "btc_usdt",
               config: %{}
             }
    end

    test "returns an error tuple when advisor is not present" do
      config =
        Tai.Config.parse(
          advisor_groups: %{
            group_a: [
              factory: TestFactoryA,
              products: "*"
            ]
          }
        )

      assert {:error, errors} = Tai.AdvisorGroups.parse_config(config)
      assert errors.group_a == [{:advisor, "must be present"}]
    end

    test "returns an error tuple when factory is not present" do
      config =
        Tai.Config.parse(
          advisor_groups: %{
            group_a: [
              advisor: TestAdvisorA,
              products: "*"
            ]
          }
        )

      assert {:error, errors} = Tai.AdvisorGroups.parse_config(config)
      assert errors.group_a == [{:factory, "must be present"}]
    end

    test "returns an error tuple when products are not present" do
      config =
        Tai.Config.parse(
          advisor_groups: %{
            group_b: [
              advisor: TestAdvisorB,
              factory: TestFactoryB
            ]
          }
        )

      assert {:error, errors} = Tai.AdvisorGroups.parse_config(config)
      assert errors.group_b == [{:products, "must be present"}]
    end
  end

  describe ".build_specs" do
    test "returns advisor specs with filtered products from the groups factory" do
      config_without_groups = Tai.Config.parse(advisor_groups: %{})

      product_1 = struct(Tai.Venues.Product, %{venue_id: :exchange_a, symbol: :btc_usd})
      product_2 = struct(Tai.Venues.Product, %{venue_id: :exchange_a, symbol: :eth_usd})
      product_3 = struct(Tai.Venues.Product, %{venue_id: :exchange_b, symbol: :btc_usd})
      product_4 = struct(Tai.Venues.Product, %{venue_id: :exchange_b, symbol: :ltc_usd})
      products = [product_1, product_2, product_3, product_4]

      assert Tai.AdvisorGroups.build_specs(config_without_groups, products) == {:ok, []}

      config_with_groups =
        Tai.Config.parse(
          advisor_groups: %{
            group_a: [
              advisor: TestAdvisorA,
              factory: TestFactoryA,
              products: "exchange_a exchange_b.ltc_usd"
            ]
          }
        )

      assert {:ok, [advisor_1, advisor_2, advisor_3]} =
               Tai.AdvisorGroups.build_specs(config_with_groups, products)

      assert {
               TestAdvisor,
               [
                 group_id: :group_a,
                 advisor_id: :advisor_exchange_a_btc_usd,
                 order_books: %{exchange_a: [:btc_usd]},
                 config: %{}
               ]
             } = advisor_1

      assert {
               TestAdvisor,
               [
                 group_id: :group_a,
                 advisor_id: :advisor_exchange_a_eth_usd,
                 order_books: %{exchange_a: [:eth_usd]},
                 config: %{}
               ]
             } = advisor_2

      assert {
               TestAdvisor,
               [
                 group_id: :group_a,
                 advisor_id: :advisor_exchange_b_ltc_usd,
                 order_books: %{exchange_b: [:ltc_usd]},
                 config: %{}
               ]
             } = advisor_3
    end

    test "surfaces the errors from .parse_config" do
      config =
        Tai.Config.parse(
          advisor_groups: %{group_a: [advisor: TestAdvisorA, factory: TestFactoryA]}
        )

      assert {:error, errors} = Tai.AdvisorGroups.build_specs(config, %{})
      assert errors.group_a == [{:products, "must be present"}]
    end
  end

  describe ".build_specs_for_group" do
    test "returns advisor specs with filtered products from the factory of the given group" do
      config_without_groups = Tai.Config.parse(advisor_groups: %{})

      product_1 = struct(Tai.Venues.Product, %{venue_id: :exchange_a, symbol: :btc_usd})
      product_2 = struct(Tai.Venues.Product, %{venue_id: :exchange_a, symbol: :eth_usd})
      product_3 = struct(Tai.Venues.Product, %{venue_id: :exchange_b, symbol: :btc_usd})
      product_4 = struct(Tai.Venues.Product, %{venue_id: :exchange_b, symbol: :ltc_usd})
      products = [product_1, product_2, product_3, product_4]

      assert Tai.AdvisorGroups.build_specs_for_group(
               config_without_groups,
               :group_a,
               products
             ) == {:ok, []}

      config_with_groups =
        Tai.Config.parse(
          advisor_groups: %{
            group_a: [
              advisor: TestAdvisorA,
              factory: TestFactoryA,
              products: "exchange_a exchange_b.ltc_usd"
            ],
            group_b: [
              advisor: TestAdvisorB,
              factory: TestFactoryA,
              products: "*"
            ]
          }
        )

      assert {:ok, [advisor_1, advisor_2, advisor_3]} =
               Tai.AdvisorGroups.build_specs_for_group(
                 config_with_groups,
                 :group_a,
                 products
               )

      assert advisor_1 == {
               TestAdvisor,
               [
                 group_id: :group_a,
                 advisor_id: :advisor_exchange_a_btc_usd,
                 order_books: %{exchange_a: [:btc_usd]},
                 config: %{}
               ]
             }

      assert advisor_2 == {
               TestAdvisor,
               [
                 group_id: :group_a,
                 advisor_id: :advisor_exchange_a_eth_usd,
                 order_books: %{exchange_a: [:eth_usd]},
                 config: %{}
               ]
             }

      assert advisor_3 == {
               TestAdvisor,
               [
                 group_id: :group_a,
                 advisor_id: :advisor_exchange_b_ltc_usd,
                 order_books: %{exchange_b: [:ltc_usd]},
                 config: %{}
               ]
             }
    end

    test "surfaces the errors from .parse_config" do
      config =
        Tai.Config.parse(
          advisor_groups: %{group_a: [advisor: TestAdvisorA, factory: TestFactoryA]}
        )

      assert {:error, errors} = Tai.AdvisorGroups.build_specs_for_group(config, :group_a, %{})
      assert errors.group_a == [{:products, "must be present"}]
    end
  end

  describe ".build_specs_for_advisor" do
    test "returns advisor specs with filtered products from the factory of the given advisor & group" do
      config_without_groups = Tai.Config.parse(advisor_groups: %{})

      product_1 = struct(Tai.Venues.Product, %{venue_id: :exchange_a, symbol: :btc_usd})
      product_2 = struct(Tai.Venues.Product, %{venue_id: :exchange_a, symbol: :eth_usd})
      product_3 = struct(Tai.Venues.Product, %{venue_id: :exchange_b, symbol: :btc_usd})
      product_4 = struct(Tai.Venues.Product, %{venue_id: :exchange_b, symbol: :ltc_usd})
      products = [product_1, product_2, product_3, product_4]

      assert Tai.AdvisorGroups.build_specs_for_advisor(
               config_without_groups,
               :group_a,
               :advisor_a,
               products
             ) == {:ok, []}

      config_with_groups =
        Tai.Config.parse(
          advisor_groups: %{
            group_a: [
              advisor: TestAdvisorA,
              factory: TestFactoryA,
              products: "exchange_a exchange_b.ltc_usd"
            ],
            group_b: [
              advisor: TestAdvisorB,
              factory: TestFactoryA,
              products: "*"
            ]
          }
        )

      assert Tai.AdvisorGroups.build_specs_for_advisor(
               config_with_groups,
               :group_a,
               :advisor_exchange_a_btc_usd,
               products
             ) == {
               :ok,
               [
                 {
                   TestAdvisor,
                   [
                     group_id: :group_a,
                     advisor_id: :advisor_exchange_a_btc_usd,
                     order_books: %{exchange_a: [:btc_usd]},
                     config: %{}
                   ]
                 }
               ]
             }
    end

    test "surfaces the errors from .parse_config" do
      config =
        Tai.Config.parse(
          advisor_groups: %{group_a: [advisor: TestAdvisorA, factory: TestFactoryA]}
        )

      assert {:error, errors} =
               Tai.AdvisorGroups.build_specs_for_advisor(config, :group_a, :advisor_a, %{})

      assert errors.group_a == [{:products, "must be present"}]
    end
  end
end
