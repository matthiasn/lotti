import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor, fireEvent } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import PricingPage from "../pages/PricingPage";

const mockFetchPricing = vi.fn();
const mockUpdatePricing = vi.fn();
const mockCreatePricing = vi.fn();

vi.mock("../api/proxy", () => ({
  fetchPricing: (...args: unknown[]) => mockFetchPricing(...args),
  updatePricing: (...args: unknown[]) => mockUpdatePricing(...args),
  createPricing: (...args: unknown[]) => mockCreatePricing(...args),
}));

function renderPage() {
  return render(
    <MemoryRouter>
      <PricingPage />
    </MemoryRouter>,
  );
}

describe("PricingPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockFetchPricing.mockResolvedValue({
      models: [
        {
          model_id: "gemini-2.5-pro",
          display_name: "Gemini Pro",
          input_price_per_1k: 0.00125,
          output_price_per_1k: 0.01,
          updated_at: "2026-01-01T00:00:00Z",
        },
        {
          model_id: "gemini-2.5-flash",
          display_name: "Gemini Flash",
          input_price_per_1k: 0.0003,
          output_price_per_1k: 0.0025,
          updated_at: "2026-01-01T00:00:00Z",
        },
      ],
    });
  });

  it("renders pricing table", async () => {
    renderPage();

    await waitFor(() => {
      expect(screen.getByText("gemini-2.5-pro")).toBeInTheDocument();
    });
    expect(screen.getByText("gemini-2.5-flash")).toBeInTheDocument();
    expect(screen.getByText("Gemini Pro")).toBeInTheDocument();
  });

  it("shows add model form when clicking Add Model", async () => {
    renderPage();

    await waitFor(() => {
      expect(screen.getByText("+ Add Model")).toBeInTheDocument();
    });

    fireEvent.click(screen.getByText("+ Add Model"));

    expect(screen.getByPlaceholderText("gemini-3.0-pro")).toBeInTheDocument();
  });

  it("enters edit mode when clicking Edit", async () => {
    renderPage();

    await waitFor(() => {
      expect(screen.getAllByText("Edit")).toHaveLength(2);
    });

    fireEvent.click(screen.getAllByText("Edit")[0]);

    expect(screen.getByText("Save")).toBeInTheDocument();
    expect(screen.getByText("Cancel")).toBeInTheDocument();
  });

  it("cancels edit mode", async () => {
    renderPage();

    await waitFor(() => {
      expect(screen.getAllByText("Edit")).toHaveLength(2);
    });

    fireEvent.click(screen.getAllByText("Edit")[0]);
    fireEvent.click(screen.getByText("Cancel"));

    await waitFor(() => {
      expect(screen.getAllByText("Edit")).toHaveLength(2);
    });
  });
});
