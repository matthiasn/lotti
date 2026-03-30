import { useCallback, useEffect, useState } from "react";
import { fetchPricing, updatePricing, createPricing } from "../api/proxy";
import type { ModelPricing } from "../types";

interface EditState {
  model_id: string;
  display_name: string;
  input_price: string;
  output_price: string;
}

export default function PricingPage() {
  const [models, setModels] = useState<ModelPricing[]>([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState<string | null>(null);
  const [editState, setEditState] = useState<EditState | null>(null);
  const [showAdd, setShowAdd] = useState(false);
  const [newModel, setNewModel] = useState<EditState>({
    model_id: "",
    display_name: "",
    input_price: "",
    output_price: "",
  });
  const [error, setError] = useState<string | null>(null);

  const loadPricing = useCallback(() => {
    setLoading(true);
    setError(null);
    fetchPricing()
      .then((res) => setModels(res.models))
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    loadPricing();
  }, [loadPricing]);

  const startEdit = (model: ModelPricing) => {
    setEditing(model.model_id);
    setEditState({
      model_id: model.model_id,
      display_name: model.display_name || "",
      input_price: String(model.input_price_per_1k),
      output_price: String(model.output_price_per_1k),
    });
  };

  const saveEdit = async () => {
    if (!editState || !editing) return;
    try {
      await updatePricing(
        editing,
        parseFloat(editState.input_price),
        parseFloat(editState.output_price),
        editState.display_name || undefined,
      );
      setEditing(null);
      setEditState(null);
      loadPricing();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Update failed");
    }
  };

  const saveNew = async () => {
    if (!newModel.model_id || !newModel.input_price || !newModel.output_price) {
      setError("All fields are required");
      return;
    }
    try {
      await createPricing(
        newModel.model_id,
        parseFloat(newModel.input_price),
        parseFloat(newModel.output_price),
        newModel.display_name || undefined,
      );
      setShowAdd(false);
      setNewModel({
        model_id: "",
        display_name: "",
        input_price: "",
        output_price: "",
      });
      loadPricing();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Create failed");
    }
  };

  if (loading) {
    return (
      <div>
        <div className="page-header">
          <h1>Model Pricing</h1>
        </div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Model ID</th>
                <th>Name</th>
                <th style={{ textAlign: "right" }}>Input $/1K</th>
                <th style={{ textAlign: "right" }}>Output $/1K</th>
                <th>Updated</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {[1, 2].map((i) => (
                <tr key={i}>
                  <td><div className="skeleton" style={{ height: 16, width: 140 }} /></td>
                  <td><div className="skeleton" style={{ height: 16, width: 100 }} /></td>
                  <td><div className="skeleton" style={{ height: 16, width: 70, marginLeft: "auto" }} /></td>
                  <td><div className="skeleton" style={{ height: 16, width: 70, marginLeft: "auto" }} /></td>
                  <td><div className="skeleton" style={{ height: 16, width: 80 }} /></td>
                  <td />
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    );
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Model Pricing</h1>
          <div className="page-subtitle">
            Manage cost per 1,000 tokens for each model
          </div>
        </div>
        <button
          className={`btn ${showAdd ? "btn--ghost" : "btn--primary"}`}
          onClick={() => setShowAdd(!showAdd)}
        >
          {showAdd ? "Cancel" : "+ Add Model"}
        </button>
      </div>

      {error && (
        <div className="error-banner">
          {error}
          <button
            className="btn btn--ghost btn--sm"
            style={{ marginLeft: "auto" }}
            onClick={() => setError(null)}
          >
            Dismiss
          </button>
        </div>
      )}

      {showAdd && (
        <div className="form-row">
          <div className="form-field">
            <label>Model ID</label>
            <input
              className="input"
              value={newModel.model_id}
              onChange={(e) =>
                setNewModel({ ...newModel, model_id: e.target.value })
              }
              placeholder="gemini-3.0-pro"
            />
          </div>
          <div className="form-field">
            <label>Display Name</label>
            <input
              className="input"
              value={newModel.display_name}
              onChange={(e) =>
                setNewModel({ ...newModel, display_name: e.target.value })
              }
              placeholder="Gemini 3.0 Pro"
            />
          </div>
          <div className="form-field">
            <label>Input $/1K</label>
            <input
              className="input"
              type="number"
              step="0.0001"
              value={newModel.input_price}
              onChange={(e) =>
                setNewModel({ ...newModel, input_price: e.target.value })
              }
              placeholder="0.00125"
            />
          </div>
          <div className="form-field">
            <label>Output $/1K</label>
            <input
              className="input"
              type="number"
              step="0.0001"
              value={newModel.output_price}
              onChange={(e) =>
                setNewModel({ ...newModel, output_price: e.target.value })
              }
              placeholder="0.01"
            />
          </div>
          <button className="btn btn--success" onClick={saveNew}>
            Save
          </button>
        </div>
      )}

      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Model ID</th>
              <th>Display Name</th>
              <th style={{ textAlign: "right" }}>Input $/1K</th>
              <th style={{ textAlign: "right" }}>Output $/1K</th>
              <th>Updated</th>
              <th style={{ width: 140 }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {models.map((model) => (
              <tr key={model.model_id}>
                {editing === model.model_id && editState ? (
                  <>
                    <td>
                      <span className="mono">{model.model_id}</span>
                    </td>
                    <td>
                      <input
                        className="input input--sm"
                        value={editState.display_name}
                        onChange={(e) =>
                          setEditState({
                            ...editState,
                            display_name: e.target.value,
                          })
                        }
                      />
                    </td>
                    <td style={{ textAlign: "right" }}>
                      <input
                        className="input input--sm"
                        type="number"
                        step="0.0001"
                        style={{ width: 100, textAlign: "right" }}
                        value={editState.input_price}
                        onChange={(e) =>
                          setEditState({
                            ...editState,
                            input_price: e.target.value,
                          })
                        }
                      />
                    </td>
                    <td style={{ textAlign: "right" }}>
                      <input
                        className="input input--sm"
                        type="number"
                        step="0.0001"
                        style={{ width: 100, textAlign: "right" }}
                        value={editState.output_price}
                        onChange={(e) =>
                          setEditState({
                            ...editState,
                            output_price: e.target.value,
                          })
                        }
                      />
                    </td>
                    <td style={{ color: "var(--color-text-tertiary)" }}>—</td>
                    <td>
                      <div style={{ display: "flex", gap: 6 }}>
                        <button
                          className="btn btn--success btn--sm"
                          onClick={saveEdit}
                        >
                          Save
                        </button>
                        <button
                          className="btn btn--sm"
                          onClick={() => {
                            setEditing(null);
                            setEditState(null);
                          }}
                        >
                          Cancel
                        </button>
                      </div>
                    </td>
                  </>
                ) : (
                  <>
                    <td>
                      <span className="mono">{model.model_id}</span>
                    </td>
                    <td style={{ fontWeight: 500 }}>
                      {model.display_name || (
                        <span style={{ color: "var(--color-text-tertiary)" }}>
                          —
                        </span>
                      )}
                    </td>
                    <td
                      style={{
                        textAlign: "right",
                        fontVariantNumeric: "tabular-nums",
                        fontFamily: "var(--font-mono)",
                        fontSize: "0.85em",
                      }}
                    >
                      ${Number(model.input_price_per_1k).toFixed(6)}
                    </td>
                    <td
                      style={{
                        textAlign: "right",
                        fontVariantNumeric: "tabular-nums",
                        fontFamily: "var(--font-mono)",
                        fontSize: "0.85em",
                      }}
                    >
                      ${Number(model.output_price_per_1k).toFixed(6)}
                    </td>
                    <td style={{ color: "var(--color-text-secondary)" }}>
                      {new Date(model.updated_at).toLocaleDateString("en-US", {
                        month: "short",
                        day: "numeric",
                        year: "numeric",
                      })}
                    </td>
                    <td>
                      <button
                        className="btn btn--sm"
                        onClick={() => startEdit(model)}
                      >
                        Edit
                      </button>
                    </td>
                  </>
                )}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
