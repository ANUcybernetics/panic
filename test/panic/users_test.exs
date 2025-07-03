defmodule Panic.UsersTest do
  use Panic.DataCase
  use ExUnitProperties
  alias Panic.Accounts.APIToken
  alias Panic.Accounts.UserAPIToken

  describe "APIToken management" do
    test "creates APIToken with replicate token successfully" do
      user = Panic.Fixtures.user()
      
      # Create an API token
      {:ok, api_token} = Ash.create(APIToken, %{
        name: "Test Token",
        replicate_token: "test_replicate_key"
      }, authorize?: false)
      
      # Associate with user
      {:ok, _} = Ash.create(UserAPIToken, %{
        user_id: user.id,
        api_token_id: api_token.id
      }, authorize?: false)
      
      # Load and verify
      user = Ash.load!(user, :api_tokens, authorize?: false)
      assert length(user.api_tokens) == 1
      assert hd(user.api_tokens).replicate_token == "test_replicate_key"
    end

    test "creates APIToken with gemini token successfully" do
      user = Panic.Fixtures.user()
      
      # Create an API token
      {:ok, api_token} = Ash.create(APIToken, %{
        name: "Test Token",
        gemini_token: "test_gemini_token_123"
      }, authorize?: false)
      
      # Associate with user
      {:ok, _} = Ash.create(UserAPIToken, %{
        user_id: user.id,
        api_token_id: api_token.id
      }, authorize?: false)
      
      # Load and verify
      user = Ash.load!(user, :api_tokens, authorize?: false)
      assert length(user.api_tokens) == 1
      assert hd(user.api_tokens).gemini_token == "test_gemini_token_123"
    end

    test "creates APIToken with allow_anonymous_use flag" do
      user = Panic.Fixtures.user()
      
      # Create an API token with anonymous access
      {:ok, api_token} = Ash.create(APIToken, %{
        name: "Anonymous Token",
        openai_token: "test_openai_key",
        allow_anonymous_use: true
      }, authorize?: false)
      
      # Associate with user
      {:ok, _} = Ash.create(UserAPIToken, %{
        user_id: user.id,
        api_token_id: api_token.id
      }, authorize?: false)
      
      assert api_token.allow_anonymous_use == true
      
      # Test anonymous resolution
      {:ok, resolved_token} = Panic.Accounts.TokenResolver.resolve_token(
        Panic.Platforms.OpenAI, 
        anonymous: true
      )
      assert resolved_token == "test_openai_key"
    end
    
    property "creates APITokens with various platform tokens" do
      token_fields = [
        :replicate_token,
        :openai_token,
        :gemini_token,
        :vestaboard_panic_1_token,
        :vestaboard_panic_2_token,
        :vestaboard_panic_3_token,
        :vestaboard_panic_4_token
      ]

      check all(
              user <- Panic.Generators.user(),
              field <- one_of(token_fields),
              value <- Panic.Generators.ascii_sentence(),
              name <- Panic.Generators.ascii_sentence()
            ) do
        # Create an API token with the specific field
        params = %{name: name}
        params = Map.put(params, field, value)
        
        {:ok, api_token} = Ash.create(APIToken, params, authorize?: false)
        
        # Associate with user
        {:ok, _} = Ash.create(UserAPIToken, %{
          user_id: user.id,
          api_token_id: api_token.id
        }, authorize?: false)
        
        assert Map.get(api_token, field) == value
      end
    end

    test "multiple users can share the same APIToken" do
      user1 = Panic.Fixtures.user()
      user2 = Panic.Fixtures.user()
      
      # Create a shared API token
      {:ok, api_token} = Ash.create(APIToken, %{
        name: "Shared Token",
        openai_token: "shared_key"
      }, authorize?: false)
      
      # Associate with both users
      {:ok, _} = Ash.create(UserAPIToken, %{
        user_id: user1.id,
        api_token_id: api_token.id
      }, authorize?: false)
      
      {:ok, _} = Ash.create(UserAPIToken, %{
        user_id: user2.id,
        api_token_id: api_token.id
      }, authorize?: false)
      
      # Verify both users have access
      user1 = Ash.load!(user1, :api_tokens, authorize?: false)
      user2 = Ash.load!(user2, :api_tokens, authorize?: false)
      
      assert length(user1.api_tokens) == 1
      assert length(user2.api_tokens) == 1
      assert hd(user1.api_tokens).id == hd(user2.api_tokens).id
    end
  end

  describe "User registration" do
    property "accepts valid registration input" do
      check all(
              email <- Panic.Generators.email(),
              password <- Panic.Generators.password()
            ) do
        user =
          Panic.Accounts.User
          |> Ash.Changeset.for_create(
            :register_with_password,
            %{email: email, password: password, password_confirmation: password}
          )
          |> Ash.create!()

        assert Ash.CiString.value(user.email) == email
      end
    end
  end
end
