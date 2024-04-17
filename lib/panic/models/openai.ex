defmodule Panic.Models.GPT3Davinci do
  @behaviour Panic.Model

  @impl true
  def info do
    %Panic.Models.ModelInfo{
      id: "text-davinci-003",
      path: "text-davinci-003",
      name: "GPT-3 Davinci",
      description: "",
      input_type: :text,
      output_type: :text,
      platform: Panic.Platforms.OpenAI
    }
  end
end

defmodule Panic.Models.GPT3Ada do
  @behaviour Panic.Model

  @impl true
  def info do
    %Panic.Models.ModelInfo{
      id: "text-ada-001",
      path: "text-ada-001",
      name: "GPT-3 Ada",
      description: "",
      input_type: :text,
      output_type: :text,
      platform: Panic.Platforms.OpenAI
    }
  end
end

defmodule Panic.Models.GPT3DavinciInstruct do
  @behaviour Panic.Model

  @impl true
  def info do
    %Panic.Models.ModelInfo{
      id: "openai:davinci-instruct-beta",
      path: "davinci-instruct-beta",
      name: "GPT-3 Davinci Instruct",
      description: "",
      input_type: :text,
      output_type: :text,
      platform: Panic.Platforms.OpenAI
    }
  end
end

defmodule Panic.Models.ChatGPT do
  @behaviour Panic.Model

  @impl true
  def info do
    %Panic.Models.ModelInfo{
      id: "openai:gpt-3.5-turbo",
      path: "gpt-3.5-turbo",
      name: "ChatGPT",
      description: "",
      input_type: :text,
      output_type: :text,
      platform: Panic.Platforms.OpenAI
    }
  end
end
